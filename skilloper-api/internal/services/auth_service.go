package services

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"go.uber.org/zap"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
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
	db        *gorm.DB
	jwtSecret []byte
	jwtExpiry time.Duration
	log       *zap.Logger
}

func NewAuthService(db *gorm.DB, jwtSecret string, jwtExpiry time.Duration, log *zap.Logger) *AuthService {
	return &AuthService{
		db:        db,
		jwtSecret: []byte(jwtSecret),
		jwtExpiry: jwtExpiry,
		log:       log,
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

	return &models.LoginResponse{
		Token: token,
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

	s.log.Debug("User logged in successfully",
		zap.Uint("user_id", user.ID))

	return &models.LoginResponse{
		Token: token,
		User: models.UserResponse{
			ID:        user.ID,
			Username:  user.Username,
			IsAdmin:   user.IsAdmin,
			CreatedAt: user.CreatedAt,
		},
	}, nil
}

func (s *AuthService) recordFailedAttempt(user *models.User) {
	user.FailedAttempts++

	updates := map[string]any{
		"failed_attempts": user.FailedAttempts,
	}

	if user.FailedAttempts >= models.MaxFailedAttempts {
		lockUntil := time.Now().Add(models.LockoutDuration)
		updates["locked_until"] = lockUntil
		s.log.Warn("Account locked due to too many failed attempts",
			zap.Uint("user_id", user.ID),
			zap.Int("failed_attempts", user.FailedAttempts),
			zap.Time("locked_until", lockUntil))
	}

	s.db.Model(user).Updates(updates)
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

// CleanupExpiredBlacklist removes expired entries from the blacklist
func (s *AuthService) CleanupExpiredBlacklist() error {
	return s.db.Where("expires_at < ?", time.Now()).Delete(&models.TokenBlacklist{}).Error
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
		s.log.Debug(operation + ": account locked")
		return nil, apperrors.ErrAccountLocked
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		s.recordFailedAttempt(&user)
		s.log.Debug(operation + ": invalid password")
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

		if err := tx.Exec(`
			DELETE FROM quiz_attempts
			WHERE quiz_id IN (SELECT id FROM quizzes WHERE user_id = ?)
		`, userID).Error; err != nil {
			return err
		}

		if err := tx.Exec(`
			DELETE FROM attempt_answers
			WHERE attempt_id IN (SELECT id FROM quiz_attempts WHERE user_id = ?)
		`, userID).Error; err != nil {
			return err
		}

		if err := tx.Where("user_id = ?", userID).Delete(&models.QuizAttempt{}).Error; err != nil {
			return err
		}

		if err := tx.Exec(`
			DELETE FROM questions
			WHERE quiz_id IN (SELECT id FROM quizzes WHERE user_id = ?)
		`, userID).Error; err != nil {
			return err
		}

		if err := tx.Where("user_id = ?", userID).Delete(&models.Quiz{}).Error; err != nil {
			return err
		}

		if err := tx.Delete(user).Error; err != nil {
			return err
		}

		return nil
	})

	if err != nil {
		return apperrors.NewDatabaseError("DELETE_ACCOUNT_FAILED", "Failed to delete account", err)
	}

	s.log.Debug("Account deleted successfully",
		zap.Uint("user_id", userID))

	return nil
}
