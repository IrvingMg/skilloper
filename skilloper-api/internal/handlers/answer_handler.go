package handlers

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

type AnswerHandler struct {
	service *services.AnswerService
	logger  *zap.Logger
}

func NewAnswerHandler(service *services.AnswerService, logger *zap.Logger) *AnswerHandler {
	return &AnswerHandler{
		service: service,
		logger:  logger,
	}
}

func (h *AnswerHandler) handleError(c *gin.Context, err error, operation string) {
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

// CreateAnswer handles POST /answers
func (h *AnswerHandler) CreateAnswer(c *gin.Context) {
	var req models.CreateAnswerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.handleError(c, apperrors.ErrInvalidJSONFormat, "parse_create_answer_request")
		return
	}

	if req.QuestionID == 0 {
		h.handleError(c, apperrors.ErrInvalidQuestionID, "invalid_question_id_zero")
		return
	}

	h.logger.Info("Validating answer for question", zap.Uint("question_id", req.QuestionID))

	result, err := h.service.ValidateAnswer(req)
	if err != nil {
		h.handleError(c, err, "validate_answer")
		return
	}

	h.logger.Info("Answer validated",
		zap.Uint("question_id", req.QuestionID),
		zap.Bool("is_correct", result.IsCorrect))
	c.JSON(http.StatusOK, result)
}
