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

type QuestionService struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewQuestionService(db *gorm.DB, logger *zap.Logger) *QuestionService {
	return &QuestionService{
		db:     db,
		logger: logger,
	}
}

// ValidateAnswer validates a user's answer against the correct answer for a question
func (s *QuestionService) ValidateAnswer(questionID uint, req models.ValidateAnswerRequest) (*models.ValidateAnswerResponse, error) {
	if req.UserAnswer == nil && len(req.UserAnswers) == 0 {
		return nil, apperrors.NewValidationError(apperrors.ErrInvalidAnswerData.Code,
			"either user_answer or user_answers must be provided")
	}

	var question models.Question
	if err := s.db.First(&question, questionID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrQuestionNotFound
		}
		return nil, apperrors.ErrFetchQuestionFailed
	}

	response := &models.ValidateAnswerResponse{}

	if question.QuestionType == models.QuestionTypeMultipleChoice {
		var correctAnswers []int
		if err := json.Unmarshal([]byte(question.CorrectAnswers), &correctAnswers); err != nil {
			s.logger.Warn("Failed to unmarshal correct answers",
				zap.Uint("question_id", questionID),
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
