package handlers

import (
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/middleware"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

type AuthHandler struct {
	service *services.AuthService
	log     *zap.Logger
}

func NewAuthHandler(service *services.AuthService, log *zap.Logger) *AuthHandler {
	return &AuthHandler{
		service: service,
		log:     log,
	}
}

func (h *AuthHandler) handleError(c *gin.Context, err error, operation string) {
	var appErr *apperrors.AppError
	if errors.As(err, &appErr) {
		switch appErr.Code {
		case "USERNAME_TAKEN":
			h.log.Warn("Username taken", zap.String("operation", operation), zap.Error(err))
			c.JSON(http.StatusConflict, gin.H{"error": appErr.Message, "code": appErr.Code})
			return
		case "INVALID_CREDENTIALS":
			h.log.Warn("Invalid credentials", zap.String("operation", operation), zap.Error(err))
			c.JSON(http.StatusUnauthorized, gin.H{"error": appErr.Message, "code": appErr.Code})
			return
		case "ACCOUNT_LOCKED":
			h.log.Warn("Account locked", zap.String("operation", operation), zap.Error(err))
			c.JSON(http.StatusTooManyRequests, gin.H{"error": appErr.Message, "code": appErr.Code})
			return
		}

		switch appErr.Type {
		case apperrors.ErrTypeValidation:
			h.log.Warn("Validation error", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(err))
			c.JSON(http.StatusBadRequest, gin.H{"error": appErr.Message, "code": appErr.Code})
		case apperrors.ErrTypeNotFound:
			h.log.Warn("Resource not found", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(err))
			c.JSON(http.StatusNotFound, gin.H{"error": appErr.Message, "code": appErr.Code})
		case apperrors.ErrTypeDatabase, apperrors.ErrTypeInternal:
			h.log.Error("Internal error", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(err))
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error", "code": appErr.Code})
		default:
			h.log.Error("Unknown error type", zap.String("operation", operation), zap.Error(err))
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error"})
		}
	} else {
		h.log.Error("Unexpected error", zap.String("operation", operation), zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error"})
	}
}

// Register handles POST /users
func (h *AuthHandler) Register(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.handleError(c, apperrors.ErrInvalidJSONFormat, "parse_register_request")
		return
	}

	user, err := h.service.Register(req)
	if err != nil {
		h.handleError(c, err, "register_user")
		return
	}

	c.JSON(http.StatusCreated, user)
}

// Login handles POST /sessions
func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.handleError(c, apperrors.ErrInvalidJSONFormat, "parse_login_request")
		return
	}

	response, err := h.service.Login(req)
	if err != nil {
		h.handleError(c, err, "login_user")
		return
	}

	c.JSON(http.StatusCreated, response)
}

// Logout handles DELETE /sessions
func (h *AuthHandler) Logout(c *gin.Context) {
	userID := middleware.GetUserID(c)

	authHeader := c.GetHeader("Authorization")
	if strings.HasPrefix(authHeader, "Bearer ") {
		token := strings.TrimPrefix(authHeader, "Bearer ")
		if expiry, err := h.service.GetTokenExpiry(token); err == nil {
			if err := h.service.BlacklistToken(token, expiry); err != nil {
				h.log.Warn("Failed to blacklist token",
					zap.Error(err))
			}
		} else {
			h.log.Warn("Failed to get token expiry for blacklisting",
				zap.Error(err))
		}
	}

	h.log.Debug("User logged out",
		zap.Uint("user_id", userID))

	c.JSON(http.StatusOK, gin.H{"message": "Logged out successfully"})
}

// GetCurrentUser handles GET /users/me
func (h *AuthHandler) GetCurrentUser(c *gin.Context) {
	userID := middleware.GetUserID(c)

	user, err := h.service.GetUserByID(userID)
	if err != nil {
		h.handleError(c, err, "get_current_user")
		return
	}

	c.JSON(http.StatusOK, user)
}

// UpdatePassword handles PUT /users/me/password
func (h *AuthHandler) UpdatePassword(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var req models.UpdatePasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.handleError(c, apperrors.ErrInvalidJSONFormat, "parse_update_password")
		return
	}

	token, err := h.service.UpdatePassword(userID, req)
	if err != nil {
		h.handleError(c, err, "update_password")
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Password updated successfully",
		"token":   token,
	})
}

// ResetHistory handles POST /users/me/history-clearance
func (h *AuthHandler) ResetHistory(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var req models.PasswordConfirmRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.handleError(c, apperrors.ErrInvalidJSONFormat, "parse_reset_history")
		return
	}

	deletedCount, err := h.service.ResetUserHistory(userID, req.Password)
	if err != nil {
		h.handleError(c, err, "reset_history")
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":       "Quiz history cleared successfully",
		"deleted_count": deletedCount,
	})
}

// DeleteAccount handles POST /users/me/deletion
func (h *AuthHandler) DeleteAccount(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var req models.PasswordConfirmRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.handleError(c, apperrors.ErrInvalidJSONFormat, "parse_delete_account")
		return
	}

	if err := h.service.DeleteAccount(userID, req.Password); err != nil {
		h.handleError(c, err, "delete_account")
		return
	}

	authHeader := c.GetHeader("Authorization")
	if strings.HasPrefix(authHeader, "Bearer ") {
		token := strings.TrimPrefix(authHeader, "Bearer ")
		if expiry, err := h.service.GetTokenExpiry(token); err == nil {
			_ = h.service.BlacklistToken(token, expiry)
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": "Account deleted successfully"})
}
