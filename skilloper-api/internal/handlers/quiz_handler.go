package handlers

import (
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
	log     *zap.Logger
	errH    *ErrorHandler
}

func NewQuizHandler(service *services.QuizService, errH *ErrorHandler, log *zap.Logger) *QuizHandler {
	return &QuizHandler{
		service: service,
		log:     log,
		errH:    errH,
	}
}

// GetQuizSummaries handles GET /quizzes/summaries
func (h *QuizHandler) GetQuizSummaries(c *gin.Context) {
	h.log.Debug("Fetching quiz summaries")

	var params models.PaginationParams
	if err := c.ShouldBindQuery(&params); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidPaginationParams, "parse_pagination_params")
		return
	}
	if !params.Validate() {
		h.errH.Handle(c, apperrors.ErrInvalidPaginationParams, "validate_pagination_params")
		return
	}

	h.log.Debug("Pagination params",
		zap.Int("limit", params.Limit),
		zap.Int("offset", params.Offset),
		zap.String("search", params.Search),
		zap.String("type", params.Type))

	result, err := h.service.GetPaginatedSummaries(params)
	if err != nil {
		h.errH.Handle(c, err, "fetch_quiz_summaries")
		return
	}

	h.log.Debug("Successfully fetched quiz summaries",
		zap.Int("count", len(result.Data)),
		zap.Int("total", result.Pagination.TotalCount))
	c.JSON(http.StatusOK, result)
}

// GetQuiz handles GET /quizzes/:id
func (h *QuizHandler) GetQuiz(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidQuizID, "parse_quiz_id")
		return
	}

	includeAnswers := c.Query("view") == ViewModeEdit

	if includeAnswers {
		userID := middleware.GetUserID(c)
		isAdmin := middleware.IsAdmin(c)
		h.log.Debug("Fetching quiz with answers for edit mode", zap.Int("id", id))

		quiz, err := h.service.GetByIDWithAnswers(uint(id), userID, isAdmin)
		if err != nil {
			h.errH.Handle(c, err, "fetch_quiz")
			return
		}

		h.log.Debug("Successfully fetched quiz with answers",
			zap.Int("id", id),
			zap.String("title", quiz.Title))
		c.JSON(http.StatusOK, quiz)
		return
	}

	h.log.Debug("Fetching quiz with dynamic shuffling", zap.Int("id", id))

	quiz, err := h.service.GetByID(uint(id))
	if err != nil {
		h.errH.Handle(c, err, "fetch_quiz")
		return
	}

	h.log.Debug("Successfully fetched quiz with shuffling",
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

	h.log.Debug("Creating new quiz")

	var req models.CreateQuizRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidJSONFormat, "parse_create_request")
		return
	}

	h.log.Debug("Creating quiz", zap.String("title", req.Title), zap.String("type", req.Type))

	quiz, err := h.service.Create(req, userID)
	if err != nil {
		h.errH.Handle(c, err, "create_quiz")
		return
	}

	h.log.Debug("Successfully created quiz", zap.Uint("id", quiz.ID), zap.String("title", quiz.Title))
	c.JSON(http.StatusCreated, quiz)
}

// UpdateQuiz handles PUT /quizzes/:id
func (h *QuizHandler) UpdateQuiz(c *gin.Context) {
	userID := middleware.GetUserID(c)
	isAdmin := middleware.IsAdmin(c)
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidQuizID, "parse_quiz_id")
		return
	}

	h.log.Debug("Updating quiz", zap.Int("id", id))

	var req models.CreateQuizRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidJSONFormat, "parse_update_request")
		return
	}

	quiz, err := h.service.Update(uint(id), req, userID, isAdmin)
	if err != nil {
		h.errH.Handle(c, err, "update_quiz")
		return
	}

	h.log.Debug("Successfully updated quiz", zap.Int("id", id), zap.String("title", quiz.Title))
	c.JSON(http.StatusOK, quiz)
}

// DeleteQuiz handles DELETE /quizzes/:id
func (h *QuizHandler) DeleteQuiz(c *gin.Context) {
	userID := middleware.GetUserID(c)
	isAdmin := middleware.IsAdmin(c)
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidQuizID, "parse_quiz_id")
		return
	}

	h.log.Debug("Deleting quiz", zap.Int("id", id))

	err = h.service.Delete(uint(id), userID, isAdmin)
	if err != nil {
		h.errH.Handle(c, err, "delete_quiz")
		return
	}

	h.log.Debug("Successfully deleted quiz", zap.Int("id", id))
	c.Status(http.StatusNoContent)
}

func (h *QuizHandler) handleImport(c *gin.Context, userID uint) {
	h.log.Debug("Importing quiz from file")

	file, err := c.FormFile("file")
	if err != nil {
		h.errH.Handle(c, apperrors.ErrFileRequired, "parse_import_file")
		return
	}

	if file.Size > models.MaxImportFileSize {
		h.errH.Handle(c, apperrors.ErrFileTooLarge, "validate_file_size")
		return
	}

	h.log.Debug("Processing uploaded file", zap.String("filename", file.Filename), zap.Int64("size", file.Size))

	title := c.Query("title")
	description := c.Query("description")

	if len(title) > models.MaxTitleLength {
		h.errH.Handle(c, apperrors.NewValidationError("TITLE_TOO_LONG",
			fmt.Sprintf("title exceeds %d character limit", models.MaxTitleLength)), "parse_csv_metadata")
		return
	}
	if len(description) > models.MaxDescriptionLength {
		h.errH.Handle(c, apperrors.NewValidationError("DESCRIPTION_TOO_LONG",
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
			h.errH.Handle(c, apperrors.NewValidationError("INVALID_MAX_OPTIONS",
				fmt.Sprintf("max_options must be a number between %d and %d", models.MinOptionsLimit, models.MaxOptionsLimit)), "parse_csv_metadata")
			return
		}
		csvMeta.MaxOptions = n
	}

	quiz, err := h.service.ImportFromFile(file, csvMeta, userID)
	if err != nil {
		h.errH.Handle(c, err, "import_quiz")
		return
	}

	h.log.Debug("Successfully imported quiz",
		zap.String("filename", file.Filename),
		zap.String("title", quiz.Title),
		zap.Int("questions", quiz.QuestionCount))

	c.JSON(http.StatusCreated, gin.H{
		"message": "Quiz imported successfully",
		"quiz":    quiz,
	})
}
