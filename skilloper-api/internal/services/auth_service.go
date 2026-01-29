package services

import (
	cryptorand "crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"math/rand/v2"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"go.uber.org/zap"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

const (
	cleanupProbabilityDenominator = 20 // 1/20 = 5% chance of cleanup per token refresh
)

var (
	// Dummy hash for timing attack prevention (hash of empty string)
	dummyHash, _ = bcrypt.GenerateFromPassword([]byte(""), models.BcryptCost)
)

// isDuplicateKeyError checks if the error is a unique constraint violation
// Works with both SQLite and PostgreSQL
func isDuplicateKeyError(err error) bool {
	if err == nil {
		return false
	}
	errStr := err.Error()
	return strings.Contains(errStr, "UNIQUE constraint failed") || // SQLite
		strings.Contains(errStr, "duplicate key value violates unique constraint") // PostgreSQL
}

type Claims struct {
	UserID   uint   `json:"user_id"`
	Username string `json:"username"`
	IsAdmin  bool   `json:"is_admin"`
	jwt.RegisteredClaims
}

type AuthService struct {
	db                 *gorm.DB
	jwtSecret          []byte
	jwtExpiry          time.Duration
	refreshTokenExpiry time.Duration
	log                *zap.Logger
}

func NewAuthService(db *gorm.DB, jwtSecret string, jwtExpiry, refreshTokenExpiry time.Duration, log *zap.Logger) *AuthService {
	return &AuthService{
		db:                 db,
		jwtSecret:          []byte(jwtSecret),
		jwtExpiry:          jwtExpiry,
		refreshTokenExpiry: refreshTokenExpiry,
		log:                log,
	}
}

func (s *AuthService) Register(req models.RegisterRequest) (*models.LoginResponse, error) {
	if err := s.validateUsername(req.Username); err != nil {
		s.log.Debug("Registration failed: invalid username",
			zap.String("reason", "validation_failed"))
		return nil, err
	}
	if err := s.validatePassword(req.Password); err != nil {
		s.log.Debug("Registration failed: invalid password",
			zap.String("reason", "password_validation_failed"))
		return nil, err
	}

	normalizedUsername := models.NormalizeUsername(req.Username)

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), models.BcryptCost)
	if err != nil {
		return nil, apperrors.NewInternalError("PASSWORD_HASH_FAILED", "Failed to hash password", err)
	}

	user := models.User{
		Username:     normalizedUsername,
		PasswordHash: string(hashedPassword),
	}

	if err := s.db.Create(&user).Error; err != nil {
		if isDuplicateKeyError(err) {
			return nil, apperrors.ErrUsernameTaken
		}
		return nil, apperrors.NewDatabaseError("USER_CREATE_FAILED", "Failed to create user", err)
	}

	s.log.Debug("User registered successfully",
		zap.Uint("user_id", user.ID))

	token, err := s.generateToken(user)
	if err != nil {
		return nil, err
	}

	familyID := uuid.New().String()
	refreshToken, err := s.generateRefreshToken(user.ID, familyID)
	if err != nil {
		return nil, err
	}

	return &models.LoginResponse{
		Token:                 token,
		RefreshToken:          refreshToken,
		ExpiresIn:             int(s.jwtExpiry.Seconds()),
		RefreshTokenExpiresIn: int(s.refreshTokenExpiry.Seconds()),
		User: models.UserResponse{
			ID:        user.ID,
			Username:  user.Username,
			IsAdmin:   user.IsAdmin,
			CreatedAt: user.CreatedAt,
		},
	}, nil
}

func (s *AuthService) Login(req models.LoginRequest) (*models.LoginResponse, error) {
	normalizedUsername := models.NormalizeUsername(req.Username)

	var user models.User
	result := s.db.Where("username = ?", normalizedUsername).First(&user)

	if result.Error == nil && user.LockedUntil != nil && time.Now().Before(*user.LockedUntil) {
		s.log.Warn("Login attempt on locked account",
			zap.Uint("user_id", user.ID),
			zap.Time("locked_until", *user.LockedUntil))
		return nil, apperrors.ErrAccountLocked
	}

	hashToCompare := dummyHash
	if result.Error == nil {
		hashToCompare = []byte(user.PasswordHash)
	}

	if err := bcrypt.CompareHashAndPassword(hashToCompare, []byte(req.Password)); err != nil || result.Error != nil {
		if result.Error != nil && !errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, apperrors.NewDatabaseError("USER_LOOKUP_FAILED", "Failed to lookup user", result.Error)
		}

		if result.Error == nil {
			s.recordFailedAttempt(&user)
		}

		s.log.Warn("Login failed: invalid credentials")

		return nil, apperrors.ErrInvalidCredentials
	}

	if user.FailedAttempts > 0 || user.LockedUntil != nil {
		s.db.Model(&user).Updates(map[string]any{
			"failed_attempts": 0,
			"locked_until":    nil,
		})
	}

	token, err := s.generateToken(user)
	if err != nil {
		return nil, err
	}

	familyID := uuid.New().String()
	refreshToken, err := s.generateRefreshToken(user.ID, familyID)
	if err != nil {
		return nil, err
	}

	s.log.Debug("User logged in successfully",
		zap.Uint("user_id", user.ID))

	return &models.LoginResponse{
		Token:                 token,
		RefreshToken:          refreshToken,
		ExpiresIn:             int(s.jwtExpiry.Seconds()),
		RefreshTokenExpiresIn: int(s.refreshTokenExpiry.Seconds()),
		User: models.UserResponse{
			ID:        user.ID,
			Username:  user.Username,
			IsAdmin:   user.IsAdmin,
			CreatedAt: user.CreatedAt,
		},
	}, nil
}

// recordFailedAttempt fails silently (logs errors but doesn't return them) so database
// issues don't break the login flow. The security feature degrades gracefully.
func (s *AuthService) recordFailedAttempt(user *models.User) {
	if err := s.db.Model(user).Update("failed_attempts", gorm.Expr("failed_attempts + 1")).Error; err != nil {
		s.log.Warn("Failed to increment failed attempts counter",
			zap.Uint("user_id", user.ID),
			zap.Error(err))
		return
	}

	if err := s.db.First(user, user.ID).Error; err != nil {
		s.log.Warn("Failed to refresh user after incrementing failed attempts",
			zap.Uint("user_id", user.ID),
			zap.Error(err))
		return
	}

	if user.FailedAttempts >= models.MaxFailedAttempts {
		lockUntil := time.Now().Add(models.LockoutDuration)
		if err := s.db.Model(user).Update("locked_until", lockUntil).Error; err != nil {
			s.log.Warn("Failed to lock account",
				zap.Uint("user_id", user.ID),
				zap.Error(err))
			return
		}
		s.log.Warn("Account locked due to too many failed attempts",
			zap.Uint("user_id", user.ID),
			zap.Int("failed_attempts", user.FailedAttempts),
			zap.Time("locked_until", lockUntil))
	}
}

func (s *AuthService) ValidateToken(tokenString string) (*Claims, error) {
	if s.isTokenBlacklisted(tokenString) {
		return nil, apperrors.ErrInvalidToken
	}

	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (any, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, apperrors.ErrInvalidToken
		}
		return s.jwtSecret, nil
	})

	if err != nil {
		return nil, apperrors.ErrInvalidToken
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, apperrors.ErrInvalidToken
	}

	if claims.IssuedAt == nil {
		return nil, apperrors.ErrInvalidToken
	}

	var user models.User
	if err := s.db.Select("tokens_invalidated_at").First(&user, claims.UserID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrInvalidToken
		}
		s.log.Warn("Failed to check token invalidation", zap.Error(err))
	} else if user.TokensInvalidatedAt != nil {
		if claims.IssuedAt.Before(*user.TokensInvalidatedAt) {
			return nil, apperrors.ErrInvalidToken
		}
	}

	return claims, nil
}

func (s *AuthService) BlacklistToken(tokenString string, expiresAt time.Time) error {
	hash := s.hashToken(tokenString)

	blacklist := models.TokenBlacklist{
		TokenHash: hash,
		ExpiresAt: expiresAt,
	}

	if err := s.db.Create(&blacklist).Error; err != nil {
		if !isDuplicateKeyError(err) {
			return err
		}
	}

	return nil
}

func (s *AuthService) isTokenBlacklisted(tokenString string) bool {
	hash := s.hashToken(tokenString)

	var blacklist models.TokenBlacklist
	result := s.db.Where("token_hash = ? AND expires_at > ?", hash, time.Now()).First(&blacklist)
	return result.Error == nil
}

func (s *AuthService) hashToken(token string) string {
	hash := sha256.Sum256([]byte(token))
	return hex.EncodeToString(hash[:])
}

func (s *AuthService) CleanupExpiredBlacklist() (int64, error) {
	result := s.db.Where("expires_at < ?", time.Now()).Delete(&models.TokenBlacklist{})
	return result.RowsAffected, result.Error
}

func (s *AuthService) CleanupExpiredRefreshTokens() (int64, error) {
	result := s.db.Where("expires_at < ?", time.Now()).Delete(&models.RefreshToken{})
	return result.RowsAffected, result.Error
}

func (s *AuthService) RunCleanupTasks() (int64, int64) {
	blacklistDeleted, err := s.CleanupExpiredBlacklist()
	if err != nil {
		s.log.Warn("Failed to cleanup expired blacklist entries", zap.Error(err))
	}

	refreshTokensDeleted, err := s.CleanupExpiredRefreshTokens()
	if err != nil {
		s.log.Warn("Failed to cleanup expired refresh tokens", zap.Error(err))
	}

	return blacklistDeleted, refreshTokensDeleted
}

// maybeRunCleanup runs cleanup with ~5% probability for opportunistic garbage collection.
func (s *AuthService) maybeRunCleanup() {
	if rand.IntN(cleanupProbabilityDenominator) == 0 {
		blacklistDeleted, refreshTokensDeleted := s.RunCleanupTasks()
		if blacklistDeleted > 0 || refreshTokensDeleted > 0 {
			s.log.Debug("Opportunistic cleanup completed",
				zap.Int64("blacklist_deleted", blacklistDeleted),
				zap.Int64("refresh_tokens_deleted", refreshTokensDeleted))
		}
	}
}

func (s *AuthService) GetUserByID(id uint) (*models.UserResponse, error) {
	var user models.User
	result := s.db.First(&user, id)
	if errors.Is(result.Error, gorm.ErrRecordNotFound) {
		return nil, apperrors.NewNotFoundError("USER_NOT_FOUND", "User not found")
	}
	if result.Error != nil {
		return nil, apperrors.NewDatabaseError("USER_LOOKUP_FAILED", "Failed to lookup user", result.Error)
	}

	return &models.UserResponse{
		ID:        user.ID,
		Username:  user.Username,
		IsAdmin:   user.IsAdmin,
		CreatedAt: user.CreatedAt,
	}, nil
}

func (s *AuthService) generateToken(user models.User) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID:   user.ID,
		Username: user.Username,
		IsAdmin:  user.IsAdmin,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(s.jwtExpiry)),
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now),
			Subject:   user.Username,
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(s.jwtSecret)
	if err != nil {
		return "", apperrors.NewInternalError("TOKEN_GENERATION_FAILED", "Failed to generate token", err)
	}

	return tokenString, nil
}

func (s *AuthService) GetTokenExpiry(tokenString string) (time.Time, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (any, error) {
		// Validate signing method to prevent algorithm confusion attacks
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, apperrors.ErrInvalidToken
		}
		return s.jwtSecret, nil
	})

	if err != nil {
		return time.Time{}, err
	}

	claims, ok := token.Claims.(*Claims)
	if !ok {
		return time.Time{}, errors.New("invalid claims")
	}

	return claims.ExpiresAt.Time, nil
}

func (s *AuthService) validateUsername(username string) error {
	if !models.ValidateUsername(username) {
		return apperrors.ErrInvalidUsername
	}
	return nil
}

func (s *AuthService) validatePassword(password string) error {
	if len(password) < models.MinPasswordLength || len(password) > models.MaxPasswordLength {
		return apperrors.ErrInvalidPassword
	}
	if !models.ValidatePasswordStrength(password) {
		return apperrors.ErrWeakPassword
	}
	return nil
}

func (s *AuthService) getUserAndVerifyPassword(userID uint, password string, operation string) (*models.User, error) {
	var user models.User
	if err := s.db.First(&user, userID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, apperrors.NewNotFoundError("USER_NOT_FOUND", "User not found")
		}
		return nil, apperrors.NewDatabaseError("USER_LOOKUP_FAILED", "Failed to lookup user", err)
	}

	if user.LockedUntil != nil && time.Now().Before(*user.LockedUntil) {
		s.log.Debug("Account locked", zap.String("operation", operation))
		return nil, apperrors.ErrAccountLocked
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		s.recordFailedAttempt(&user)
		s.log.Debug("Invalid password", zap.String("operation", operation))
		return nil, apperrors.ErrInvalidCredentials
	}

	if user.FailedAttempts > 0 || user.LockedUntil != nil {
		s.db.Model(&user).Updates(map[string]any{
			"failed_attempts": 0,
			"locked_until":    nil,
		})
	}

	return &user, nil
}

func (s *AuthService) UpdatePassword(userID uint, req models.UpdatePasswordRequest) (string, error) {
	if err := s.validatePassword(req.NewPassword); err != nil {
		return "", err
	}

	if req.CurrentPassword == req.NewPassword {
		return "", apperrors.ErrSamePassword
	}

	user, err := s.getUserAndVerifyPassword(userID, req.CurrentPassword, "Password update failed")
	if err != nil {
		return "", err
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), models.BcryptCost)
	if err != nil {
		return "", apperrors.NewInternalError("PASSWORD_HASH_FAILED", "Failed to hash password", err)
	}

	now := time.Now()
	if err := s.db.Model(user).Updates(map[string]any{
		"password_hash":         string(hashedPassword),
		"tokens_invalidated_at": now,
	}).Error; err != nil {
		return "", apperrors.NewDatabaseError("PASSWORD_UPDATE_FAILED", "Failed to update password", err)
	}

	token, err := s.generateToken(*user)
	if err != nil {
		return "", err
	}

	s.log.Debug("Password updated successfully",
		zap.Uint("user_id", userID))

	return token, nil
}

func (s *AuthService) ResetUserHistory(userID uint, password string) (int64, error) {
	_, err := s.getUserAndVerifyPassword(userID, password, "Reset history failed")
	if err != nil {
		return 0, err
	}

	var deletedCount int64
	err = s.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Exec(`
			DELETE FROM attempt_answers
			WHERE attempt_id IN (SELECT id FROM quiz_attempts WHERE user_id = ?)
		`, userID).Error; err != nil {
			return err
		}

		result := tx.Where("user_id = ?", userID).Delete(&models.QuizAttempt{})
		if result.Error != nil {
			return result.Error
		}
		deletedCount = result.RowsAffected

		return nil
	})

	if err != nil {
		return 0, apperrors.NewDatabaseError("RESET_HISTORY_FAILED", "Failed to reset quiz history", err)
	}

	s.log.Debug("Quiz history reset successfully",
		zap.Uint("user_id", userID),
		zap.Int64("deleted_attempts", deletedCount))

	return deletedCount, nil
}

func (s *AuthService) DeleteAccount(userID uint, password string) error {
	user, err := s.getUserAndVerifyPassword(userID, password, "Account deletion failed")
	if err != nil {
		return err
	}

	if user.IsAdmin {
		return apperrors.ErrAdminSelfDeletion
	}

	err = s.db.Transaction(func(tx *gorm.DB) error {
		if err := s.deleteUserQuizAttempts(tx, userID); err != nil {
			return err
		}
		if err := s.deleteUserAttempts(tx, userID); err != nil {
			return err
		}
		if err := s.deleteUserQuizzes(tx, userID); err != nil {
			return err
		}
		return tx.Delete(user).Error
	})

	if err != nil {
		return apperrors.NewDatabaseError("DELETE_ACCOUNT_FAILED", "Failed to delete account", err)
	}

	s.log.Debug("Account deleted successfully",
		zap.Uint("user_id", userID))

	return nil
}

// deleteUserQuizAttempts deletes all attempt answers for quizzes owned by the user
func (s *AuthService) deleteUserQuizAttempts(tx *gorm.DB, userID uint) error {
	// Delete attempt answers for attempts on quizzes owned by this user
	if err := tx.Exec(`
		DELETE FROM attempt_answers
		WHERE attempt_id IN (
			SELECT qa.id FROM quiz_attempts qa
			JOIN quizzes q ON qa.quiz_id = q.id
			WHERE q.user_id = ?
		)
	`, userID).Error; err != nil {
		return err
	}

	// Delete quiz attempts on quizzes owned by this user
	return tx.Exec(`
		DELETE FROM quiz_attempts
		WHERE quiz_id IN (SELECT id FROM quizzes WHERE user_id = ?)
	`, userID).Error
}

// deleteUserAttempts deletes all attempts made by the user
func (s *AuthService) deleteUserAttempts(tx *gorm.DB, userID uint) error {
	// Delete attempt answers for this user's attempts
	if err := tx.Exec(`
		DELETE FROM attempt_answers
		WHERE attempt_id IN (SELECT id FROM quiz_attempts WHERE user_id = ?)
	`, userID).Error; err != nil {
		return err
	}

	// Delete this user's quiz attempts
	return tx.Where("user_id = ?", userID).Delete(&models.QuizAttempt{}).Error
}

// deleteUserQuizzes deletes all quizzes and their questions owned by the user
func (s *AuthService) deleteUserQuizzes(tx *gorm.DB, userID uint) error {
	// Delete questions for quizzes owned by this user
	if err := tx.Exec(`
		DELETE FROM questions
		WHERE quiz_id IN (SELECT id FROM quizzes WHERE user_id = ?)
	`, userID).Error; err != nil {
		return err
	}

	// Delete quizzes owned by this user
	return tx.Where("user_id = ?", userID).Delete(&models.Quiz{}).Error
}

// generateRefreshToken creates a new refresh token and stores it in the database
func (s *AuthService) generateRefreshToken(userID uint, familyID string) (string, error) {
	return s.generateRefreshTokenTx(s.db, userID, familyID)
}

// generateRefreshTokenTx creates a new refresh token using the provided database handle (supports transactions)
func (s *AuthService) generateRefreshTokenTx(db *gorm.DB, userID uint, familyID string) (string, error) {
	tokenBytes := make([]byte, 32)
	if _, err := cryptorand.Read(tokenBytes); err != nil {
		return "", apperrors.NewInternalError("REFRESH_TOKEN_GENERATION_FAILED", "Failed to generate refresh token", err)
	}

	tokenString := base64.URLEncoding.EncodeToString(tokenBytes)
	tokenHash := s.hashToken(tokenString)

	refreshToken := models.RefreshToken{
		TokenHash: tokenHash,
		UserID:    userID,
		FamilyID:  familyID,
		ExpiresAt: time.Now().Add(s.refreshTokenExpiry),
	}

	if err := db.Create(&refreshToken).Error; err != nil {
		return "", apperrors.NewDatabaseError("REFRESH_TOKEN_CREATE_FAILED", "Failed to store refresh token", err)
	}

	return tokenString, nil
}

// RefreshTokens validates a refresh token and returns a new token pair
func (s *AuthService) RefreshTokens(refreshTokenString string) (*models.TokenPairResponse, error) {
	tokenHash := s.hashToken(refreshTokenString)

	var storedToken models.RefreshToken
	result := s.db.Where("token_hash = ?", tokenHash).First(&storedToken)
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrInvalidToken
		}
		return nil, apperrors.NewDatabaseError("REFRESH_TOKEN_LOOKUP_FAILED", "Failed to lookup refresh token", result.Error)
	}

	// Check if token is revoked (potential token reuse attack)
	if storedToken.Revoked {
		s.revokeTokenFamily(storedToken.FamilyID)
		s.log.Warn("Refresh token reuse detected, revoking family",
			zap.String("family_id", storedToken.FamilyID),
			zap.Uint("user_id", storedToken.UserID))
		return nil, apperrors.ErrInvalidToken
	}

	// Check expiration
	if time.Now().After(storedToken.ExpiresAt) {
		return nil, apperrors.ErrInvalidToken
	}

	// Verify user still exists and tokens haven't been invalidated
	var user models.User
	if err := s.db.First(&user, storedToken.UserID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrInvalidToken
		}
		return nil, apperrors.NewDatabaseError("USER_LOOKUP_FAILED", "Failed to lookup user", err)
	}

	// Check TokensInvalidatedAt (password change invalidates all tokens)
	if user.TokensInvalidatedAt != nil && storedToken.CreatedAt.Before(*user.TokensInvalidatedAt) {
		return nil, apperrors.ErrInvalidToken
	}

	// Perform token rotation atomically in a transaction
	var accessToken, newRefreshToken string
	txErr := s.db.Transaction(func(tx *gorm.DB) error {
		// Revoke the current refresh token (rotation)
		now := time.Now()
		if updateErr := tx.Model(&storedToken).Updates(map[string]any{
			"revoked":    true,
			"revoked_at": now,
		}).Error; updateErr != nil {
			s.log.Error("Failed to revoke refresh token during rotation",
				zap.Error(updateErr),
				zap.Uint("token_id", storedToken.ID))
			return apperrors.NewDatabaseError("TOKEN_REVOCATION_FAILED", "Failed to revoke token", updateErr)
		}

		// Generate new access token
		var tokenErr error
		accessToken, tokenErr = s.generateToken(user)
		if tokenErr != nil {
			return tokenErr
		}

		// Generate new refresh token in same family (using transaction)
		newRefreshToken, tokenErr = s.generateRefreshTokenTx(tx, user.ID, storedToken.FamilyID)
		if tokenErr != nil {
			return tokenErr
		}

		return nil
	})

	if txErr != nil {
		return nil, txErr
	}

	s.log.Debug("Tokens refreshed successfully",
		zap.Uint("user_id", user.ID))

	// Opportunistic cleanup on token operations
	s.maybeRunCleanup()

	return &models.TokenPairResponse{
		AccessToken:           accessToken,
		RefreshToken:          newRefreshToken,
		ExpiresIn:             int(s.jwtExpiry.Seconds()),
		RefreshTokenExpiresIn: int(s.refreshTokenExpiry.Seconds()),
	}, nil
}

// RevokeUserRefreshTokens revokes all refresh tokens for a user (used on logout)
func (s *AuthService) RevokeUserRefreshTokens(userID uint) error {
	now := time.Now()
	return s.db.Model(&models.RefreshToken{}).
		Where("user_id = ? AND revoked = false", userID).
		Updates(map[string]any{
			"revoked":    true,
			"revoked_at": now,
		}).Error
}

// revokeTokenFamily revokes all tokens in a family (used on token reuse detection)
func (s *AuthService) revokeTokenFamily(familyID string) {
	now := time.Now()
	if err := s.db.Model(&models.RefreshToken{}).
		Where("family_id = ? AND revoked = false", familyID).
		Updates(map[string]any{
			"revoked":    true,
			"revoked_at": now,
		}).Error; err != nil {
		s.log.Error("Failed to revoke token family",
			zap.Error(err),
			zap.String("family_id", familyID))
	}
}
