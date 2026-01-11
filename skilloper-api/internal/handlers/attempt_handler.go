package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/middleware"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

type AttemptHandler struct {
	service *services.AttemptService
	log     *zap.Logger
	errH    *ErrorHandler
}

func NewAttemptHandler(service *services.AttemptService, errH *ErrorHandler, log *zap.Logger) *AttemptHandler {
	return &AttemptHandler{
		service: service,
		log:     log,
		errH:    errH,
	}
}

// CreateAttempt handles POST /attempts
func (h *AttemptHandler) CreateAttempt(c *gin.Context) {
	userID := middleware.GetUserID(c)
	h.log.Debug("Creating new quiz attempt", zap.Uint("user_id", userID))

	var req models.StartAttemptRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidJSONFormat, "parse_create_attempt_request")
		return
	}

	h.log.Debug("Creating attempt",
		zap.Uint("user_id", userID),
		zap.Uint("quiz_id", req.QuizID))

	attempt, err := h.service.Start(userID, req)
	if err != nil {
		h.errH.Handle(c, err, "create_attempt")
		return
	}

	h.log.Debug("Successfully created attempt",
		zap.Uint("id", attempt.ID),
		zap.Uint("user_id", attempt.UserID))
	c.JSON(http.StatusCreated, attempt)
}

// UpdateAttempt handles PATCH /attempts/:id
func (h *AttemptHandler) UpdateAttempt(c *gin.Context) {
	userID := middleware.GetUserID(c)
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidAttemptID, "parse_attempt_id")
		return
	}

	var req models.UpdateAttemptRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidJSONFormat, "parse_update_attempt_request")
		return
	}

	h.log.Debug("Updating quiz attempt", zap.Uint("user_id", userID), zap.Int("id", id), zap.String("status", string(req.Status)))

	attempt, err := h.service.Update(userID, uint(id), req)
	if err != nil {
		h.errH.Handle(c, err, "update_attempt")
		return
	}

	h.log.Debug("Successfully updated attempt",
		zap.Int("id", id),
		zap.String("status", string(attempt.Status)))
	c.JSON(http.StatusOK, attempt)
}

// GetAttempts handles GET /attempts
func (h *AttemptHandler) GetAttempts(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var params models.PaginationParams
	if err := c.ShouldBindQuery(&params); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidPaginationParams, "parse_pagination_params")
		return
	}
	if !params.Validate() {
		h.errH.Handle(c, apperrors.ErrInvalidPaginationParams, "validate_pagination_params")
		return
	}

	h.log.Debug("Fetching attempts for user",
		zap.Uint("user_id", userID),
		zap.Int("limit", params.Limit),
		zap.Int("offset", params.Offset),
		zap.String("search", params.Search),
		zap.String("type", params.Type))

	result, err := h.service.GetPaginatedByUserID(userID, params)
	if err != nil {
		h.errH.Handle(c, err, "fetch_attempts")
		return
	}

	h.log.Debug("Successfully fetched attempts",
		zap.Uint("user_id", userID),
		zap.Int("count", len(result.Data)),
		zap.Int("total", result.Pagination.TotalCount))
	c.JSON(http.StatusOK, result)
}

// GetAttempt handles GET /attempts/:id
func (h *AttemptHandler) GetAttempt(c *gin.Context) {
	userID := middleware.GetUserID(c)
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidAttemptID, "parse_attempt_id")
		return
	}

	h.log.Debug("Fetching attempt", zap.Uint("user_id", userID), zap.Int("id", id))

	attempt, err := h.service.GetByID(userID, uint(id))
	if err != nil {
		h.errH.Handle(c, err, "fetch_attempt")
		return
	}

	h.log.Debug("Successfully fetched attempt",
		zap.Int("id", id),
		zap.String("quiz_title", attempt.QuizTitle))
	c.JSON(http.StatusOK, attempt)
}
