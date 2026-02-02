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
	db  *gorm.DB
	log *zap.Logger
}

func NewAnswerService(db *gorm.DB, log *zap.Logger) *AnswerService {
	return &AnswerService{
		db:  db,
		log: log,
	}
}

func (s *AnswerService) ValidateAnswer(req models.CreateAnswerRequest) (*models.AnswerResponse, error) {
	if len(req.UserAnswers) == 0 {
		return nil, apperrors.NewValidationError(apperrors.ErrInvalidAnswerData.Code,
			"user_answers must be provided")
	}

	var question models.Question
	if err := s.db.First(&question, req.QuestionID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrQuestionNotFound
		}
		return nil, apperrors.ErrFetchQuestionFailed
	}

	var correctAnswers []int
	if err := json.Unmarshal([]byte(question.CorrectAnswers), &correctAnswers); err != nil {
		s.log.Debug("Failed to unmarshal correct answers",
			zap.Uint("question_id", req.QuestionID),
			zap.Error(err))
		return nil, apperrors.ErrFetchQuestionFailed
	}

	return &models.AnswerResponse{
		IsCorrect:      validation.ValidateMultipleChoice(req.UserAnswers, correctAnswers),
		CorrectAnswers: correctAnswers,
	}, nil
}
