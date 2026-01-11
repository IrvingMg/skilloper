package handlers

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
)

// ErrorHandler provides centralized error handling for HTTP handlers
type ErrorHandler struct {
	log *zap.Logger
}

// NewErrorHandler creates a new ErrorHandler
func NewErrorHandler(log *zap.Logger) *ErrorHandler {
	return &ErrorHandler{log: log}
}

// Handle processes an error and sends the appropriate HTTP response
func (h *ErrorHandler) Handle(c *gin.Context, err error, operation string) {
	var appErr *apperrors.AppError
	if errors.As(err, &appErr) {
		h.handleAppError(c, appErr, operation)
		return
	}

	h.log.Error("Unexpected error", zap.String("operation", operation), zap.Error(err))
	c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error"})
}

func (h *ErrorHandler) handleAppError(c *gin.Context, appErr *apperrors.AppError, operation string) {
	// Handle specific error codes that need non-standard HTTP status codes
	switch appErr.Code {
	case "USERNAME_TAKEN":
		h.log.Warn("Username taken", zap.String("operation", operation), zap.Error(appErr))
		c.JSON(http.StatusConflict, gin.H{"error": appErr.Message, "code": appErr.Code})
		return
	case "ACCOUNT_LOCKED":
		h.log.Warn("Account locked", zap.String("operation", operation), zap.Error(appErr))
		c.JSON(http.StatusTooManyRequests, gin.H{"error": appErr.Message, "code": appErr.Code})
		return
	}

	// Handle by error type
	switch appErr.Type {
	case apperrors.ErrTypeValidation:
		h.log.Warn("Validation error", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(appErr))
		c.JSON(http.StatusBadRequest, gin.H{"error": appErr.Message, "code": appErr.Code})
	case apperrors.ErrTypeNotFound:
		h.log.Warn("Resource not found", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(appErr))
		c.JSON(http.StatusNotFound, gin.H{"error": appErr.Message, "code": appErr.Code})
	case apperrors.ErrTypeAuthentication:
		h.log.Warn("Authentication error", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(appErr))
		c.JSON(http.StatusUnauthorized, gin.H{"error": appErr.Message, "code": appErr.Code})
	case apperrors.ErrTypeAuthorization:
		h.log.Warn("Authorization error", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(appErr))
		c.JSON(http.StatusForbidden, gin.H{"error": appErr.Message, "code": appErr.Code})
	case apperrors.ErrTypeDatabase, apperrors.ErrTypeInternal:
		h.log.Error("Internal error", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(appErr))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error", "code": appErr.Code})
	default:
		h.log.Error("Unknown error type", zap.String("operation", operation), zap.Error(appErr))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error"})
	}
}
