package services

import (
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"go.uber.org/zap"

	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

// createTestAuthService creates an AuthService for testing token operations
// Note: DB is nil, so only non-DB operations can be tested
func createTestAuthService() *AuthService {
	logger := zap.NewNop() // No-op logger for tests
	return &AuthService{
		db:        nil,
		jwtSecret: []byte("test-secret-key-for-testing-purposes"),
		jwtExpiry: 24 * time.Hour,
		logger:    logger,
	}
}

func TestAuthService_GenerateToken(t *testing.T) {
	s := createTestAuthService()

	user := models.User{
		ID:       42,
		Username: "testuser",
		IsAdmin:  false,
	}

	token, err := s.generateToken(user)
	if err != nil {
		t.Fatalf("generateToken() error = %v", err)
	}

	if token == "" {
		t.Error("generateToken() returned empty token")
	}

	// Verify token has 3 parts (header.payload.signature)
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Errorf("token has %d parts, want 3", len(parts))
	}
}

func TestAuthService_GenerateToken_AdminUser(t *testing.T) {
	s := createTestAuthService()

	user := models.User{
		ID:       1,
		Username: "admin",
		IsAdmin:  true,
	}

	token, err := s.generateToken(user)
	if err != nil {
		t.Fatalf("generateToken() error = %v", err)
	}

	// Parse and verify claims
	parsedToken, err := jwt.ParseWithClaims(token, &Claims{}, func(token *jwt.Token) (any, error) {
		return s.jwtSecret, nil
	})
	if err != nil {
		t.Fatalf("Failed to parse token: %v", err)
	}

	claims, ok := parsedToken.Claims.(*Claims)
	if !ok {
		t.Fatal("Failed to cast claims")
	}

	if claims.UserID != 1 {
		t.Errorf("UserID = %d, want 1", claims.UserID)
	}
	if claims.Username != "admin" {
		t.Errorf("Username = %q, want %q", claims.Username, "admin")
	}
	if !claims.IsAdmin {
		t.Error("IsAdmin = false, want true")
	}
}

func TestAuthService_GetTokenExpiry(t *testing.T) {
	s := createTestAuthService()

	user := models.User{ID: 1, Username: "test"}
	token, err := s.generateToken(user)
	if err != nil {
		t.Fatalf("generateToken() error = %v", err)
	}

	expiry, err := s.GetTokenExpiry(token)
	if err != nil {
		t.Fatalf("GetTokenExpiry() error = %v", err)
	}

	// Expiry should be approximately 24 hours from now
	expectedExpiry := time.Now().Add(s.jwtExpiry)
	diff := expiry.Sub(expectedExpiry)
	if diff < -time.Minute || diff > time.Minute {
		t.Errorf("Expiry diff from expected = %v, want within 1 minute", diff)
	}
}

func TestAuthService_GetTokenExpiry_InvalidToken(t *testing.T) {
	s := createTestAuthService()

	_, err := s.GetTokenExpiry("invalid-token")
	if err == nil {
		t.Error("GetTokenExpiry() should fail with invalid token")
	}
}

func TestAuthService_HashToken(t *testing.T) {
	s := createTestAuthService()

	// Same input should always produce same hash
	hash1 := s.hashToken("test-token")
	hash2 := s.hashToken("test-token")
	if hash1 != hash2 {
		t.Error("hashToken() should be deterministic")
	}

	// Different inputs should produce different hashes
	hash3 := s.hashToken("different-token")
	if hash1 == hash3 {
		t.Error("hashToken() should produce different hashes for different inputs")
	}

	// Hash should be hex-encoded SHA256 (64 chars)
	if len(hash1) != 64 {
		t.Errorf("hashToken() length = %d, want 64", len(hash1))
	}
}

func TestIsDuplicateKeyError(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want bool
	}{
		{"nil error", nil, false},
		{"sqlite unique", errors.New("UNIQUE constraint failed: users.username"), true},
		{"postgres unique", errors.New("duplicate key value violates unique constraint"), true},
		{"other error", errors.New("some other error"), false},
		{"partial match sqlite", errors.New("Error: UNIQUE constraint failed"), true},
		{"partial match postgres", errors.New("pq: duplicate key value violates unique constraint"), true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := isDuplicateKeyError(tt.err); got != tt.want {
				t.Errorf("isDuplicateKeyError() = %v, want %v", got, tt.want)
			}
		})
	}
}

// Note: ValidateToken requires a database connection for blacklist checking,
// so we test JWT parsing directly using jwt.ParseWithClaims instead.

func TestJWTParsing_InvalidFormat(t *testing.T) {
	secret := []byte("test-secret")

	tests := []struct {
		name  string
		token string
	}{
		{"empty token", ""},
		{"no dots", "invalidtoken"},
		{"one dot", "invalid.token"},
		{"garbage", "not-a-jwt-at-all"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := jwt.ParseWithClaims(tt.token, &Claims{}, func(token *jwt.Token) (any, error) {
				return secret, nil
			})
			if err == nil {
				t.Error("jwt.Parse() should fail with invalid token format")
			}
		})
	}
}

func TestJWTParsing_WrongSignature(t *testing.T) {
	correctSecret := []byte("correct-secret")
	wrongSecret := []byte("wrong-secret")

	// Create a token with the wrong secret
	claims := &Claims{
		UserID:   1,
		Username: "test",
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, _ := token.SignedString(wrongSecret)

	// Try to validate with the correct secret
	_, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (any, error) {
		return correctSecret, nil
	})
	if err == nil {
		t.Error("jwt.Parse() should fail with wrong signature")
	}
}

func TestJWTParsing_ExpiredToken(t *testing.T) {
	secret := []byte("test-secret")

	// Create an expired token
	claims := &Claims{
		UserID:   1,
		Username: "test",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(-time.Hour)), // Expired
			IssuedAt:  jwt.NewNumericDate(time.Now().Add(-2 * time.Hour)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, _ := token.SignedString(secret)

	_, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (any, error) {
		return secret, nil
	})
	if err == nil {
		t.Error("jwt.Parse() should fail with expired token")
	}
}

func TestJWTParsing_WrongAlgorithm(t *testing.T) {
	// Create a token with 'none' algorithm
	claims := &Claims{
		UserID:   1,
		Username: "test",
	}
	token := jwt.NewWithClaims(jwt.SigningMethodNone, claims)
	tokenString, _ := token.SignedString(jwt.UnsafeAllowNoneSignatureType)

	// Try to parse requiring HMAC
	_, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (any, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return []byte("secret"), nil
	})
	if err == nil {
		t.Error("jwt.Parse() should fail with 'none' algorithm")
	}
}

func TestAuthService_ValidateUsername(t *testing.T) {
	s := createTestAuthService()

	tests := []struct {
		name     string
		username string
		wantErr  bool
	}{
		{"valid username", "testuser", false},
		{"valid with underscore", "test_user", false},
		{"valid min length", "abcdef", false},
		{"too short", "abc", true},
		{"empty", "", true},
		{"invalid chars", "test@user", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := s.validateUsername(tt.username)
			if (err != nil) != tt.wantErr {
				t.Errorf("validateUsername() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestAuthService_ValidatePassword(t *testing.T) {
	s := createTestAuthService()

	tests := []struct {
		name     string
		password string
		wantErr  bool
	}{
		{"valid password", "Password1", false},
		{"valid complex", "MyP@ssw0rd!", false},
		{"too short", "Pass1", true},
		{"no uppercase", "password1", true},
		{"no lowercase", "PASSWORD1", true},
		{"no digit", "Password", true},
		{"empty", "", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := s.validatePassword(tt.password)
			if (err != nil) != tt.wantErr {
				t.Errorf("validatePassword() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestAuthService_TokenClaims(t *testing.T) {
	s := createTestAuthService()

	user := models.User{
		ID:       123,
		Username: "claimtest",
		IsAdmin:  true,
	}

	token, err := s.generateToken(user)
	if err != nil {
		t.Fatalf("generateToken() error = %v", err)
	}

	// Parse token manually to verify claims
	parsedToken, err := jwt.ParseWithClaims(token, &Claims{}, func(token *jwt.Token) (any, error) {
		return s.jwtSecret, nil
	})
	if err != nil {
		t.Fatalf("jwt.Parse() error = %v", err)
	}

	claims, ok := parsedToken.Claims.(*Claims)
	if !ok || !parsedToken.Valid {
		t.Fatal("Invalid token claims")
	}

	if claims.UserID != 123 {
		t.Errorf("UserID = %d, want 123", claims.UserID)
	}
	if claims.Username != "claimtest" {
		t.Errorf("Username = %q, want %q", claims.Username, "claimtest")
	}
	if !claims.IsAdmin {
		t.Error("IsAdmin = false, want true")
	}
	if claims.Subject != "claimtest" {
		t.Errorf("Subject = %q, want %q", claims.Subject, "claimtest")
	}
	if claims.ExpiresAt == nil {
		t.Error("ExpiresAt should not be nil")
	}
	if claims.IssuedAt == nil {
		t.Error("IssuedAt should not be nil")
	}
	if claims.NotBefore == nil {
		t.Error("NotBefore should not be nil")
	}
}
