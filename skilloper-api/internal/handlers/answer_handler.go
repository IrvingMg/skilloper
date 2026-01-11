package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

type AnswerHandler struct {
	service *services.AnswerService
	log     *zap.Logger
	errH    *ErrorHandler
}

func NewAnswerHandler(service *services.AnswerService, errH *ErrorHandler, log *zap.Logger) *AnswerHandler {
	return &AnswerHandler{
		service: service,
		log:     log,
		errH:    errH,
	}
}

// CreateAnswer handles POST /answers
func (h *AnswerHandler) CreateAnswer(c *gin.Context) {
	var req models.CreateAnswerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidJSONFormat, "parse_create_answer_request")
		return
	}

	if req.QuestionID == 0 {
		h.errH.Handle(c, apperrors.ErrInvalidQuestionID, "invalid_question_id_zero")
		return
	}

	h.log.Debug("Validating answer for question", zap.Uint("question_id", req.QuestionID))

	result, err := h.service.ValidateAnswer(req)
	if err != nil {
		h.errH.Handle(c, err, "validate_answer")
		return
	}

	h.log.Debug("Answer validated",
		zap.Uint("question_id", req.QuestionID),
		zap.Bool("is_correct", result.IsCorrect))
	c.JSON(http.StatusOK, result)
}
