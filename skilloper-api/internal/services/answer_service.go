package services

import (
	"encoding/json"
	"errors"

	"go.uber.org/zap"
	"gorm.io/gorm"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
	"github.com/irvingmg/skilloper/skilloper-api/internal/validation"
)

type AnswerService struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewAnswerService(db *gorm.DB, logger *zap.Logger) *AnswerService {
	return &AnswerService{
		db:     db,
		logger: logger,
	}
}

func (s *AnswerService) ValidateAnswer(req models.CreateAnswerRequest) (*models.AnswerResponse, error) {
	if req.UserAnswer == nil && len(req.UserAnswers) == 0 {
		return nil, apperrors.NewValidationError(apperrors.ErrInvalidAnswerData.Code,
			"either user_answer or user_answers must be provided")
	}

	var question models.Question
	if err := s.db.First(&question, req.QuestionID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrQuestionNotFound
		}
		return nil, apperrors.ErrFetchQuestionFailed
	}

	response := &models.AnswerResponse{}

	if question.QuestionType == models.QuestionTypeMultipleChoice {
		var correctAnswers []int
		if err := json.Unmarshal([]byte(question.CorrectAnswers), &correctAnswers); err != nil {
			s.logger.Warn("Failed to unmarshal correct answers",
				zap.Uint("question_id", req.QuestionID),
				zap.Error(err))
			return nil, apperrors.ErrFetchQuestionFailed
		}

		response.IsCorrect = validation.ValidateMultipleChoice(req.UserAnswers, correctAnswers)
		response.CorrectAnswers = correctAnswers
	} else {
		if req.UserAnswer != nil {
			response.IsCorrect = *req.UserAnswer == question.CorrectAnswer
		}
		response.CorrectAnswer = &question.CorrectAnswer
	}

	return response, nil
}
