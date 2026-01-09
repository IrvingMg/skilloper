package handlers

import (
	"errors"
	"fmt"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/middleware"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

const (
	ViewModeEdit = "edit"
)

type QuizHandler struct {
	service *services.QuizService
	logger  *zap.Logger
}

func NewQuizHandler(service *services.QuizService, logger *zap.Logger) *QuizHandler {
	return &QuizHandler{
		service: service,
		logger:  logger,
	}
}

func (h *QuizHandler) handleError(c *gin.Context, err error, operation string) {
	var appErr *apperrors.AppError
	if errors.As(err, &appErr) {
		switch appErr.Type {
		case apperrors.ErrTypeValidation:
			h.logger.Warn("Validation error", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(err))
			c.JSON(http.StatusBadRequest, gin.H{"error": appErr.Message, "code": appErr.Code})
		case apperrors.ErrTypeNotFound:
			h.logger.Warn("Resource not found", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(err))
			c.JSON(http.StatusNotFound, gin.H{"error": appErr.Message, "code": appErr.Code})
		case apperrors.ErrTypeAuthorization:
			h.logger.Warn("Authorization error", zap.String("operation", operation), zap.String("code", appErr.Code), zap.Error(err))
			c.JSON(http.StatusForbidden, gin.H{"error": appErr.Message, "code": appErr.Code})
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

// GetQuizSummaries handles GET /quizzes/summaries
func (h *QuizHandler) GetQuizSummaries(c *gin.Context) {
	h.logger.Debug("Fetching quiz summaries")

	var params models.PaginationParams
	if err := c.ShouldBindQuery(&params); err != nil {
		h.handleError(c, apperrors.ErrInvalidPaginationParams, "parse_pagination_params")
		return
	}
	if !params.Validate() {
		h.handleError(c, apperrors.ErrInvalidPaginationParams, "validate_pagination_params")
		return
	}

	h.logger.Debug("Pagination params",
		zap.Int("limit", params.Limit),
		zap.Int("offset", params.Offset),
		zap.String("search", params.Search),
		zap.String("type", params.Type))

	result, err := h.service.GetPaginatedSummaries(params)
	if err != nil {
		h.handleError(c, err, "fetch_quiz_summaries")
		return
	}

	h.logger.Debug("Successfully fetched quiz summaries",
		zap.Int("count", len(result.Data)),
		zap.Int("total", result.Pagination.TotalCount))
	c.JSON(http.StatusOK, result)
}

// GetQuiz handles GET /quizzes/:id
func (h *QuizHandler) GetQuiz(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.handleError(c, apperrors.ErrInvalidQuizID, "parse_quiz_id")
		return
	}

	includeAnswers := c.Query("view") == ViewModeEdit

	if includeAnswers {
		userID := middleware.GetUserID(c)
		isAdmin := middleware.IsAdmin(c)
		h.logger.Debug("Fetching quiz with answers for edit mode", zap.Int("id", id))

		quiz, err := h.service.GetByIDWithAnswers(uint(id), userID, isAdmin)
		if err != nil {
			h.handleError(c, err, "fetch_quiz")
			return
		}

		h.logger.Debug("Successfully fetched quiz with answers",
			zap.Int("id", id),
			zap.String("title", quiz.Title))
		c.JSON(http.StatusOK, quiz)
		return
	}

	h.logger.Debug("Fetching quiz with dynamic shuffling", zap.Int("id", id))

	quiz, err := h.service.GetByID(uint(id))
	if err != nil {
		h.handleError(c, err, "fetch_quiz")
		return
	}

	h.logger.Debug("Successfully fetched quiz with shuffling",
		zap.Int("id", id),
		zap.String("title", quiz.Title))
	c.JSON(http.StatusOK, quiz)
}

// CreateQuiz handles POST /quizzes
func (h *QuizHandler) CreateQuiz(c *gin.Context) {
	userID := middleware.GetUserID(c)
	contentType := c.ContentType()

	if contentType == "multipart/form-data" || c.Request.MultipartForm != nil {
		h.handleImport(c, userID)
		return
	}

	h.logger.Debug("Creating new quiz")

	var req models.CreateQuizRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.handleError(c, apperrors.ErrInvalidJSONFormat, "parse_create_request")
		return
	}

	h.logger.Debug("Creating quiz", zap.String("title", req.Title), zap.String("type", req.Type))

	quiz, err := h.service.Create(req, userID)
	if err != nil {
		h.handleError(c, err, "create_quiz")
		return
	}

	h.logger.Debug("Successfully created quiz", zap.Uint("id", quiz.ID), zap.String("title", quiz.Title))
	c.JSON(http.StatusCreated, quiz)
}

// UpdateQuiz handles PUT /quizzes/:id
func (h *QuizHandler) UpdateQuiz(c *gin.Context) {
	userID := middleware.GetUserID(c)
	isAdmin := middleware.IsAdmin(c)
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.handleError(c, apperrors.ErrInvalidQuizID, "parse_quiz_id")
		return
	}

	h.logger.Debug("Updating quiz", zap.Int("id", id))

	var req models.CreateQuizRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.handleError(c, apperrors.ErrInvalidJSONFormat, "parse_update_request")
		return
	}

	quiz, err := h.service.Update(uint(id), req, userID, isAdmin)
	if err != nil {
		h.handleError(c, err, "update_quiz")
		return
	}

	h.logger.Debug("Successfully updated quiz", zap.Int("id", id), zap.String("title", quiz.Title))
	c.JSON(http.StatusOK, quiz)
}

// DeleteQuiz handles DELETE /quizzes/:id
func (h *QuizHandler) DeleteQuiz(c *gin.Context) {
	userID := middleware.GetUserID(c)
	isAdmin := middleware.IsAdmin(c)
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.handleError(c, apperrors.ErrInvalidQuizID, "parse_quiz_id")
		return
	}

	h.logger.Debug("Deleting quiz", zap.Int("id", id))

	err = h.service.Delete(uint(id), userID, isAdmin)
	if err != nil {
		h.handleError(c, err, "delete_quiz")
		return
	}

	h.logger.Debug("Successfully deleted quiz", zap.Int("id", id))
	c.Status(http.StatusNoContent)
}

func (h *QuizHandler) handleImport(c *gin.Context, userID uint) {
	h.logger.Debug("Importing quiz from file")

	file, err := c.FormFile("file")
	if err != nil {
		h.handleError(c, apperrors.ErrFileRequired, "parse_import_file")
		return
	}

	h.logger.Debug("Processing uploaded file", zap.String("filename", file.Filename), zap.Int64("size", file.Size))

	title := c.Query("title")
	description := c.Query("description")

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

	if maxOpts := c.Query("max_options"); maxOpts != "" {
		n, err := strconv.Atoi(maxOpts)
		if err != nil || n < models.MinOptionsLimit || n > models.MaxOptionsLimit {
			h.handleError(c, apperrors.NewValidationError("INVALID_MAX_OPTIONS",
				fmt.Sprintf("max_options must be a number between %d and %d", models.MinOptionsLimit, models.MaxOptionsLimit)), "parse_csv_metadata")
			return
		}
		csvMeta.MaxOptions = n
	}

	quiz, err := h.service.ImportFromFile(file, csvMeta, userID)
	if err != nil {
		h.handleError(c, err, "import_quiz")
		return
	}

	h.logger.Debug("Successfully imported quiz",
		zap.String("filename", file.Filename),
		zap.String("title", quiz.Title),
		zap.Int("questions", quiz.QuestionCount))

	c.JSON(http.StatusCreated, gin.H{
		"message": "Quiz imported successfully",
		"quiz":    quiz,
	})
}
