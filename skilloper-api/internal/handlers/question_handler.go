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

type QuestionHandler struct {
	service *services.QuestionService
	logger  *zap.Logger
}

func NewQuestionHandler(service *services.QuestionService, logger *zap.Logger) *QuestionHandler {
	return &QuestionHandler{
		service: service,
		logger:  logger,
	}
}

// handleError processes application errors and returns appropriate HTTP responses
func (h *QuestionHandler) handleError(c *gin.Context, err error, operation string) {
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

// ValidateAnswer handles POST /questions/:id/validate
// Used for practice mode to get immediate feedback after answering
func (h *QuestionHandler) ValidateAnswer(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		h.handleError(c, apperrors.ErrInvalidQuestionID, "parse_question_id")
		return
	}

	if id == 0 {
		h.handleError(c, apperrors.ErrInvalidQuestionID, "invalid_question_id_zero")
		return
	}

	h.logger.Info("Validating answer for question", zap.Uint64("id", id))

	var req models.ValidateAnswerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.handleError(c, apperrors.ErrInvalidJSONFormat, "parse_validate_answer_request")
		return
	}

	result, err := h.service.ValidateAnswer(uint(id), req)
	if err != nil {
		h.handleError(c, err, "validate_answer")
		return
	}

	h.logger.Info("Answer validated",
		zap.Uint64("question_id", id),
		zap.Bool("is_correct", result.IsCorrect))
	c.JSON(http.StatusOK, result)
}
