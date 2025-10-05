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

type QuestionnaireHandler struct {
	service *services.QuestionnaireService
	logger  *zap.Logger
}

func NewQuestionnaireHandler(service *services.QuestionnaireService, logger *zap.Logger) *QuestionnaireHandler {
	return &QuestionnaireHandler{
		service: service,
		logger:  logger,
	}
}

// handleError processes application errors and returns appropriate HTTP responses
func (h *QuestionnaireHandler) handleError(c *gin.Context, err error, operation string) {
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
		// Handle non-application errors
		h.logger.Error("Unexpected error", zap.String("operation", operation), zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error"})
	}
}

// GetQuestionnaireSummaries handles GET /questionnaires/summaries
func (h *QuestionnaireHandler) GetQuestionnaireSummaries(c *gin.Context) {
	h.logger.Info("Fetching questionnaire summaries")

	summaries, err := h.service.GetAllSummaries()
	if err != nil {
		h.handleError(c, err, "fetch_questionnaire_summaries")
		return
	}

	h.logger.Info("Successfully fetched questionnaire summaries",
		zap.Int("count", len(summaries)))
	c.JSON(http.StatusOK, summaries)
}

// GetQuestionnaire handles GET /questionnaires/{id}
func (h *QuestionnaireHandler) GetQuestionnaire(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.handleError(c, apperrors.ErrInvalidQuestionnaireID, "parse_questionnaire_id")
		return
	}

	h.logger.Info("Fetching questionnaire with dynamic shuffling", zap.Int("id", id))

	questionnaire, err := h.service.GetByID(uint(id))
	if err != nil {
		h.handleError(c, err, "fetch_questionnaire")
		return
	}

	h.logger.Info("Successfully fetched questionnaire with shuffling",
		zap.Int("id", id),
		zap.String("title", questionnaire.Title))
	c.JSON(http.StatusOK, questionnaire)
}

// CreateQuestionnaire handles POST /questionnaires
func (h *QuestionnaireHandler) CreateQuestionnaire(c *gin.Context) {
	h.logger.Info("Creating new questionnaire")

	var req models.CreateQuestionnaireRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.handleError(c, apperrors.ErrInvalidJSONFormat, "parse_create_request")
		return
	}

	h.logger.Info("Creating questionnaire", zap.String("title", req.Title), zap.String("type", req.Type))

	questionnaire, err := h.service.Create(req)
	if err != nil {
		h.handleError(c, err, "create_questionnaire")
		return
	}

	h.logger.Info("Successfully created questionnaire", zap.Uint("id", questionnaire.ID), zap.String("title", questionnaire.Title))
	c.JSON(http.StatusCreated, questionnaire)
}

// UpdateQuestionnaire handles PUT /questionnaires/{id}
func (h *QuestionnaireHandler) UpdateQuestionnaire(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.handleError(c, apperrors.ErrInvalidQuestionnaireID, "parse_questionnaire_id")
		return
	}

	h.logger.Info("Updating questionnaire", zap.Int("id", id))

	var req models.CreateQuestionnaireRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.handleError(c, apperrors.ErrInvalidJSONFormat, "parse_update_request")
		return
	}

	questionnaire, err := h.service.Update(uint(id), req)
	if err != nil {
		h.handleError(c, err, "update_questionnaire")
		return
	}

	h.logger.Info("Successfully updated questionnaire", zap.Int("id", id), zap.String("title", questionnaire.Title))
	c.JSON(http.StatusOK, questionnaire)
}

// DeleteQuestionnaire handles DELETE /questionnaires/{id}
func (h *QuestionnaireHandler) DeleteQuestionnaire(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.handleError(c, apperrors.ErrInvalidQuestionnaireID, "parse_questionnaire_id")
		return
	}

	h.logger.Info("Deleting questionnaire", zap.Int("id", id))

	err = h.service.Delete(uint(id))
	if err != nil {
		h.handleError(c, err, "delete_questionnaire")
		return
	}

	h.logger.Info("Successfully deleted questionnaire", zap.Int("id", id))
	c.Status(http.StatusNoContent)
}

// ImportQuestionnaire handles POST /questionnaires/import
func (h *QuestionnaireHandler) ImportQuestionnaire(c *gin.Context) {
	h.logger.Info("Importing questionnaire from file")

	// Parse multipart form
	file, err := c.FormFile("file")
	if err != nil {
		h.handleError(c, apperrors.ErrFileRequired, "parse_import_file")
		return
	}

	h.logger.Info("Processing uploaded file", zap.String("filename", file.Filename), zap.Int64("size", file.Size))

	// Import questionnaire from file
	questionnaire, err := h.service.ImportFromFile(file)
	if err != nil {
		h.handleError(c, err, "import_questionnaire")
		return
	}

	h.logger.Info("Successfully imported questionnaire",
		zap.String("filename", file.Filename),
		zap.String("title", questionnaire.Title),
		zap.Int("questions", questionnaire.QuestionCount))

	c.JSON(http.StatusOK, gin.H{
		"message":       "Questionnaire imported successfully",
		"questionnaire": questionnaire,
	})
}
