package handlers

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

type AttemptHandler struct {
	service *services.AttemptService
	logger  *zap.Logger
}

func NewAttemptHandler(service *services.AttemptService, logger *zap.Logger) *AttemptHandler {
	return &AttemptHandler{
		service: service,
		logger:  logger,
	}
}

// handleError processes application errors and returns appropriate HTTP responses
func (h *AttemptHandler) handleError(c *gin.Context, err error, operation string) {
	var appErr *apperrors.AppError
	if errors.As(err, &appErr) {
		switch appErr.Type {
		case apperrors.ErrTypeValidation:
			h.logger.Warn("Validation error", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(err))
			c.JSON(http.StatusBadRequest, gin.H{"error": appErr.Message, "code": appErr.Code})
		case apperrors.ErrTypeNotFound:
			h.logger.Warn("Resource not found", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(err))
			c.JSON(http.StatusNotFound, gin.H{"error": appErr.Message, "code": appErr.Code})
		case apperrors.ErrTypeDatabase, apperrors.ErrTypeInternal:
			h.logger.Error("Internal error", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(err))
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error", "code": appErr.Code})
		default:
			h.logger.Error("Unknown error type", zap.String("operation", operation), zap.Error(err))
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error"})
		}
	} else {
		h.logger.Error("Unexpected error", zap.String("operation", operation), zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error"})
	}
}

// StartAttempt handles POST /attempts/start
func (h *AttemptHandler) StartAttempt(c *gin.Context) {
	h.logger.Info("Starting new quiz attempt")

	var req models.StartAttemptRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.handleError(c, apperrors.ErrInvalidJSONFormat, "parse_start_attempt_request")
		return
	}

	h.logger.Info("Starting attempt",
		zap.String("device_id", req.DeviceID),
		zap.Uint("questionnaire_id", req.QuestionnaireID))

	attempt, err := h.service.Start(req)
	if err != nil {
		h.handleError(c, err, "start_attempt")
		return
	}

	h.logger.Info("Successfully started attempt",
		zap.Uint("id", attempt.ID),
		zap.String("device_id", attempt.DeviceID))
	c.JSON(http.StatusCreated, attempt)
}

// CompleteAttempt handles POST /attempts/:id/complete
func (h *AttemptHandler) CompleteAttempt(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.handleError(c, apperrors.ErrInvalidAttemptID, "parse_attempt_id")
		return
	}

	h.logger.Info("Completing quiz attempt", zap.Int("id", id))

	var req models.CompleteAttemptRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.handleError(c, apperrors.ErrInvalidJSONFormat, "parse_complete_attempt_request")
		return
	}

	attempt, err := h.service.Complete(uint(id), req)
	if err != nil {
		h.handleError(c, err, "complete_attempt")
		return
	}

	h.logger.Info("Successfully completed attempt",
		zap.Int("id", id),
		zap.Int("score", attempt.Score))
	c.JSON(http.StatusOK, attempt)
}

// GetAttempts handles GET /attempts?device_id=xxx
func (h *AttemptHandler) GetAttempts(c *gin.Context) {
	deviceID := c.Query("device_id")
	if deviceID == "" {
		h.handleError(c, apperrors.ErrDeviceIDRequired, "parse_device_id")
		return
	}

	h.logger.Info("Fetching attempts for device", zap.String("device_id", deviceID))

	attempts, err := h.service.GetByDeviceID(deviceID)
	if err != nil {
		h.handleError(c, err, "fetch_attempts")
		return
	}

	h.logger.Info("Successfully fetched attempts",
		zap.String("device_id", deviceID),
		zap.Int("count", len(attempts)))
	c.JSON(http.StatusOK, attempts)
}

// GetAttempt handles GET /attempts/:id
func (h *AttemptHandler) GetAttempt(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.handleError(c, apperrors.ErrInvalidAttemptID, "parse_attempt_id")
		return
	}

	h.logger.Info("Fetching attempt", zap.Int("id", id))

	attempt, err := h.service.GetByID(uint(id))
	if err != nil {
		h.handleError(c, err, "fetch_attempt")
		return
	}

	h.logger.Info("Successfully fetched attempt",
		zap.Int("id", id),
		zap.String("questionnaire_title", attempt.QuestionnaireTitle))
	c.JSON(http.StatusOK, attempt)
}
