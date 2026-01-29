package handlers

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/gin-gonic/gin/binding"
	"go.uber.org/zap"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/middleware"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

type AuthHandler struct {
	service *services.AuthService
	log     *zap.Logger
	errH    *ErrorHandler
}

func NewAuthHandler(service *services.AuthService, errH *ErrorHandler, log *zap.Logger) *AuthHandler {
	return &AuthHandler{
		service: service,
		log:     log,
		errH:    errH,
	}
}

// Register handles POST /users
func (h *AuthHandler) Register(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindBodyWith(&req, binding.JSON); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidJSONFormat, "parse_register_request")
		return
	}

	user, err := h.service.Register(req)
	if err != nil {
		h.errH.Handle(c, err, "register_user")
		return
	}

	c.JSON(http.StatusCreated, user)
}

// Login handles POST /sessions
func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindBodyWith(&req, binding.JSON); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidJSONFormat, "parse_login_request")
		return
	}

	response, err := h.service.Login(req)
	if err != nil {
		h.errH.Handle(c, err, "login_user")
		return
	}

	c.JSON(http.StatusCreated, response)
}

// RefreshToken handles POST /sessions/refresh
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req models.RefreshTokenRequest
	// Use ShouldBindBodyWith because the rate limiter middleware may have already read the body
	if err := c.ShouldBindBodyWith(&req, binding.JSON); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidJSONFormat, "parse_refresh_request")
		return
	}

	response, err := h.service.RefreshTokens(req.RefreshToken)
	if err != nil {
		h.errH.Handle(c, err, "refresh_token")
		return
	}

	c.JSON(http.StatusOK, response)
}

// Logout handles DELETE /sessions
func (h *AuthHandler) Logout(c *gin.Context) {
	userID := middleware.GetUserID(c)

	// Blacklist current access token
	authHeader := c.GetHeader("Authorization")
	if strings.HasPrefix(authHeader, "Bearer ") {
		token := strings.TrimPrefix(authHeader, "Bearer ")
		if expiry, err := h.service.GetTokenExpiry(token); err == nil {
			if err := h.service.BlacklistToken(token, expiry); err != nil {
				h.log.Warn("Failed to blacklist token during logout",
					zap.Uint("user_id", userID),
					zap.Error(err))
			} else {
				h.log.Debug("Access token blacklisted",
					zap.Uint("user_id", userID))
			}
		} else {
			h.log.Warn("Failed to get token expiry for blacklisting",
				zap.Uint("user_id", userID),
				zap.Error(err))
		}
	}

	// Revoke all refresh tokens for this user
	if err := h.service.RevokeUserRefreshTokens(userID); err != nil {
		h.log.Warn("Failed to revoke refresh tokens during logout",
			zap.Uint("user_id", userID),
			zap.Error(err))
	} else {
		h.log.Debug("Refresh tokens revoked",
			zap.Uint("user_id", userID))
	}

	h.log.Info("User logged out",
		zap.Uint("user_id", userID))

	c.JSON(http.StatusOK, gin.H{"message": "Logged out successfully"})
}

// GetCurrentUser handles GET /users/me
func (h *AuthHandler) GetCurrentUser(c *gin.Context) {
	userID := middleware.GetUserID(c)

	user, err := h.service.GetUserByID(userID)
	if err != nil {
		h.errH.Handle(c, err, "get_current_user")
		return
	}

	c.JSON(http.StatusOK, user)
}

// UpdatePassword handles PUT /users/me/password
func (h *AuthHandler) UpdatePassword(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var req models.UpdatePasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidJSONFormat, "parse_update_password")
		return
	}

	token, err := h.service.UpdatePassword(userID, req)
	if err != nil {
		h.errH.Handle(c, err, "update_password")
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
		h.errH.Handle(c, apperrors.ErrInvalidJSONFormat, "parse_reset_history")
		return
	}

	deletedCount, err := h.service.ResetUserHistory(userID, req.Password)
	if err != nil {
		h.errH.Handle(c, err, "reset_history")
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
		h.errH.Handle(c, apperrors.ErrInvalidJSONFormat, "parse_delete_account")
		return
	}

	if err := h.service.DeleteAccount(userID, req.Password); err != nil {
		h.errH.Handle(c, err, "delete_account")
		return
	}

	authHeader := c.GetHeader("Authorization")
	if strings.HasPrefix(authHeader, "Bearer ") {
		token := strings.TrimPrefix(authHeader, "Bearer ")
		if expiry, err := h.service.GetTokenExpiry(token); err == nil {
			_ = h.service.BlacklistToken(token, expiry)
		}
	}

	h.log.Info("Account deleted",
		zap.Uint("user_id", userID))

	c.JSON(http.StatusOK, gin.H{"message": "Account deleted successfully"})
}
