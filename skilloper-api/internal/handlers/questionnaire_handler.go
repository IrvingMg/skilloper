package handlers

import (
	"errors"
	"fmt"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

// View mode constants for GET /questionnaires/{id}
const (
	ViewModeEdit = "edit" // Returns correct answers for editing
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

	// Parse pagination params
	var params models.PaginationParams
	if err := c.ShouldBindQuery(&params); err != nil {
		h.handleError(c, apperrors.ErrInvalidPaginationParams, "parse_pagination_params")
		return
	}
	if !params.Validate() {
		h.handleError(c, apperrors.ErrInvalidPaginationParams, "validate_pagination_params")
		return
	}

	h.logger.Info("Pagination params",
		zap.Int("limit", params.Limit),
		zap.Int("offset", params.Offset),
		zap.String("search", params.Search),
		zap.String("type", params.Type))

	result, err := h.service.GetPaginatedSummaries(params)
	if err != nil {
		h.handleError(c, err, "fetch_questionnaire_summaries")
		return
	}

	h.logger.Info("Successfully fetched questionnaire summaries",
		zap.Int("count", len(result.Data)),
		zap.Int("total", result.Pagination.TotalCount))
	c.JSON(http.StatusOK, result)
}

// GetQuestionnaire handles GET /questionnaires/{id}
// Use ?view=edit query param to include correct answers (for edit mode)
func (h *QuestionnaireHandler) GetQuestionnaire(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.handleError(c, apperrors.ErrInvalidQuestionnaireID, "parse_questionnaire_id")
		return
	}

	// Check for edit mode query param (?view=edit)
	includeAnswers := c.Query("view") == ViewModeEdit

	if includeAnswers {
		h.logger.Info("Fetching questionnaire with answers for edit mode", zap.Int("id", id))

		questionnaire, err := h.service.GetByIDWithAnswers(uint(id))
		if err != nil {
			h.handleError(c, err, "fetch_questionnaire")
			return
		}

		h.logger.Info("Successfully fetched questionnaire with answers",
			zap.Int("id", id),
			zap.String("title", questionnaire.Title))
		c.JSON(http.StatusOK, questionnaire)
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
// For CSV files, accepts optional query params: title, description, type, max_options
func (h *QuestionnaireHandler) ImportQuestionnaire(c *gin.Context) {
	h.logger.Info("Importing questionnaire from file")

	// Parse multipart form
	file, err := c.FormFile("file")
	if err != nil {
		h.handleError(c, apperrors.ErrFileRequired, "parse_import_file")
		return
	}

	h.logger.Info("Processing uploaded file", zap.String("filename", file.Filename), zap.Int64("size", file.Size))

	// Parse CSV metadata from query params (used for CSV imports)
	title := c.Query("title")
	description := c.Query("description")

	// Validate length limits (using centralized constants from models)
	if len(title) > models.MaxTitleLength {
		h.handleError(c, apperrors.NewValidationError("TITLE_TOO_LONG",
			fmt.Sprintf("title exceeds %d character limit", models.MaxTitleLength)), "parse_csv_metadata")
		return
	}
	if len(description) > models.MaxDescriptionLength {
		h.handleError(c, apperrors.NewValidationError("DESCRIPTION_TOO_LONG",
			fmt.Sprintf("description exceeds %d character limit", models.MaxDescriptionLength)), "parse_csv_metadata")
		return
	}

	csvMeta := services.CSVMetadata{
		Title:       title,
		Description: description,
		Type:        c.Query("type"),
	}

	// Validate max_options (using centralized constants)
	if maxOpts := c.Query("max_options"); maxOpts != "" {
		n, err := strconv.Atoi(maxOpts)
		if err != nil || n < models.MinOptionsLimit || n > models.MaxOptionsLimit {
			h.handleError(c, apperrors.NewValidationError("INVALID_MAX_OPTIONS",
				fmt.Sprintf("max_options must be a number between %d and %d", models.MinOptionsLimit, models.MaxOptionsLimit)), "parse_csv_metadata")
			return
		}
		csvMeta.MaxOptions = n
	}

	// Import questionnaire from file
	questionnaire, err := h.service.ImportFromFile(file, csvMeta)
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
