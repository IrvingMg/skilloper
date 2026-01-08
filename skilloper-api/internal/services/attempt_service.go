package services

import (
	"encoding/json"
	"errors"
	"strings"
	"time"

	"go.uber.org/zap"
	"gorm.io/gorm"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
	"github.com/irvingmg/skilloper/skilloper-api/internal/validation"
)

type AttemptService struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewAttemptService(db *gorm.DB, logger *zap.Logger) *AttemptService {
	return &AttemptService{
		db:     db,
		logger: logger,
	}
}

func (s *AttemptService) Start(userID uint, req models.StartAttemptRequest) (*models.AttemptResponse, error) {
	if userID == 0 {
		return nil, apperrors.ErrUnauthorized
	}

	if req.QuizID == 0 {
		return nil, apperrors.NewValidationError(apperrors.ErrInvalidAttemptData.Code,
			"quiz ID is required")
	}

	var attempt models.QuizAttempt

	err := s.db.Transaction(func(tx *gorm.DB) error {
		var quiz models.Quiz
		if err := tx.First(&quiz, req.QuizID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return apperrors.ErrQuizNotFound
			}
			return err
		}

		var questionCount int64
		if err := tx.Model(&models.Question{}).
			Where("quiz_id = ?", req.QuizID).
			Count(&questionCount).Error; err != nil {
			return err
		}

		staleThreshold := time.Now().Add(-time.Duration(models.StaleAttemptHours) * time.Hour)
		if err := tx.Model(&models.QuizAttempt{}).
			Where("user_id = ? AND quiz_id = ? AND status = ? AND created_at < ?",
				userID, req.QuizID, models.AttemptStatusInProgress, staleThreshold).
			Updates(map[string]interface{}{
				"status":       models.AttemptStatusAbandoned,
				"completed_at": time.Now(),
			}).Error; err != nil {
			s.logger.Warn("Failed to clean up stale attempts", zap.Error(err))
		}

		var existingCount int64
		if err := tx.Model(&models.QuizAttempt{}).
			Where("user_id = ? AND quiz_id = ?", userID, req.QuizID).
			Count(&existingCount).Error; err != nil {
			return err
		}
		attemptNumber := int(existingCount) + 1

		attempt = models.QuizAttempt{
			UserID:        userID,
			QuizID:        req.QuizID,
			QuizTitle:     quiz.Title,
			QuizType:      quiz.Type,
			AttemptNumber: attemptNumber,
			Status:        models.AttemptStatusInProgress,
			TotalCount:    int(questionCount),
		}

		if err := tx.Create(&attempt).Error; err != nil {
			return err
		}

		return nil
	})

	if err != nil {
		var appErr *apperrors.AppError
		if errors.As(err, &appErr) {
			return nil, appErr
		}
		return nil, apperrors.ErrCreateAttemptFailed
	}

	response := s.convertToResponse(attempt)
	return &response, nil
}

func (s *AttemptService) Update(userID uint, attemptID uint, req models.UpdateAttemptRequest) (*models.AttemptResponse, error) {
	if req.Status != models.AttemptStatusCompleted {
		return nil, apperrors.NewValidationError("INVALID_STATUS", "only 'completed' status is supported")
	}

	if len(req.Answers) == 0 {
		return s.abandon(userID, attemptID)
	}

	return s.complete(userID, attemptID, req.Answers)
}

func (s *AttemptService) abandon(userID uint, attemptID uint) (*models.AttemptResponse, error) {
	var attempt models.QuizAttempt

	err := s.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.First(&attempt, attemptID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return apperrors.ErrAttemptNotFound
			}
			return err
		}

		if attempt.UserID != userID {
			return apperrors.ErrAttemptNotFound
		}

		if attempt.Status != models.AttemptStatusInProgress {
			return apperrors.NewValidationError(apperrors.ErrInvalidAttemptData.Code,
				"attempt is already completed")
		}

		now := time.Now()
		attempt.Status = models.AttemptStatusAbandoned
		attempt.CompletedAt = &now

		return tx.Save(&attempt).Error
	})

	if err != nil {
		var appErr *apperrors.AppError
		if errors.As(err, &appErr) {
			return nil, appErr
		}
		return nil, apperrors.ErrCreateAttemptFailed
	}

	response := s.convertToResponse(attempt)
	return &response, nil
}

func (s *AttemptService) complete(userID uint, attemptID uint, answers []models.UserAnswerRequest) (*models.AttemptResponse, error) {
	var attempt models.QuizAttempt

	err := s.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.First(&attempt, attemptID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return apperrors.ErrAttemptNotFound
			}
			return err
		}

		if attempt.UserID != userID {
			return apperrors.ErrAttemptNotFound
		}

		if attempt.Status != models.AttemptStatusInProgress {
			return apperrors.NewValidationError(apperrors.ErrInvalidAttemptData.Code,
				"attempt is already completed")
		}

		var quiz models.Quiz
		if err := tx.Preload("Questions").First(&quiz, attempt.QuizID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return apperrors.ErrQuizNotFound
			}
			return err
		}

		questionMap := make(map[uint]models.Question)
		for _, q := range quiz.Questions {
			questionMap[q.ID] = q
		}

		seenQuestions := make(map[uint]bool)
		correctCount := 0
		for _, answerReq := range answers {
			if seenQuestions[answerReq.QuestionID] {
				s.logger.Warn("Duplicate question submission ignored",
					zap.Uint("question_id", answerReq.QuestionID),
					zap.Uint("attempt_id", attemptID))
				continue
			}
			seenQuestions[answerReq.QuestionID] = true

			question, found := questionMap[answerReq.QuestionID]
			if !found {
				s.logger.Warn("Question not found in quiz",
					zap.Uint("question_id", answerReq.QuestionID),
					zap.Uint("quiz_id", attempt.QuizID))
				continue
			}

			var options []string
			if err := json.Unmarshal([]byte(question.Options), &options); err != nil {
				s.logger.Warn("Failed to unmarshal options",
					zap.Uint("question_id", question.ID),
					zap.Error(err))
				options = []string{}
			}

			var isCorrect bool
			var correctAnswer *int
			correctAnswers := []int{}
			var userAnswersJSON, correctAnswersJSON, optionsJSON string

			if question.QuestionType == models.QuestionTypeMultipleChoice {
				if err := json.Unmarshal([]byte(question.CorrectAnswers), &correctAnswers); err != nil {
					s.logger.Warn("Failed to unmarshal correct answers",
						zap.Uint("question_id", question.ID),
						zap.Error(err))
					correctAnswers = []int{}
				}

				isCorrect = validation.ValidateMultipleChoice(answerReq.UserAnswers, correctAnswers)

				if len(answerReq.UserAnswers) > 0 {
					if userAnswersBytes, err := json.Marshal(answerReq.UserAnswers); err != nil {
						s.logger.Warn("Failed to marshal user answers",
							zap.Uint("question_id", question.ID),
							zap.Error(err))
					} else {
						userAnswersJSON = string(userAnswersBytes)
					}
				}
				if len(correctAnswers) > 0 {
					if correctAnswersBytes, err := json.Marshal(correctAnswers); err != nil {
						s.logger.Warn("Failed to marshal correct answers",
							zap.Uint("question_id", question.ID),
							zap.Error(err))
					} else {
						correctAnswersJSON = string(correctAnswersBytes)
					}
				}
			} else {
				ca := question.CorrectAnswer
				correctAnswer = &ca

				if answerReq.UserAnswer != nil {
					isCorrect = *answerReq.UserAnswer == question.CorrectAnswer
				}
			}

			if isCorrect {
				correctCount++
			}

			if len(options) > 0 {
				if optionsBytes, err := json.Marshal(options); err != nil {
					s.logger.Warn("Failed to marshal options",
						zap.Uint("question_id", question.ID),
						zap.Error(err))
				} else {
					optionsJSON = string(optionsBytes)
				}
			}

			answer := models.AttemptAnswer{
				AttemptID:      attemptID,
				QuestionID:     answerReq.QuestionID,
				QuestionText:   question.QuestionText,
				QuestionType:   question.QuestionType,
				UserAnswer:     answerReq.UserAnswer,
				UserAnswers:    userAnswersJSON,
				CorrectAnswer:  correctAnswer,
				CorrectAnswers: correctAnswersJSON,
				Options:        optionsJSON,
				IsCorrect:      isCorrect,
			}
			attempt.Answers = append(attempt.Answers, answer)
		}

		totalCount := len(quiz.Questions)
		var score int
		if totalCount > 0 {
			score = (correctCount * models.ScorePercentage) / totalCount
		}

		now := time.Now()
		attempt.Status = models.AttemptStatusCompleted
		attempt.Score = score
		attempt.CorrectCount = correctCount
		attempt.TotalCount = totalCount
		attempt.CompletedAt = &now

		if err := tx.Omit("Answers").Save(&attempt).Error; err != nil {
			return err
		}

		for i := range attempt.Answers {
			if err := tx.Create(&attempt.Answers[i]).Error; err != nil {
				return err
			}
		}

		return nil
	})

	if err != nil {
		var appErr *apperrors.AppError
		if errors.As(err, &appErr) {
			return nil, appErr
		}
		return nil, apperrors.ErrCreateAttemptFailed
	}

	response := s.convertToResponse(attempt)
	return &response, nil
}

func (s *AttemptService) GetPaginatedByUserID(userID uint, params models.PaginationParams) (models.PaginatedAttemptSummaries, error) {
	if userID == 0 {
		return models.PaginatedAttemptSummaries{}, apperrors.ErrUnauthorized
	}

	query := s.db.Model(&models.QuizAttempt{}).Where("user_id = ?", userID)

	if params.Search != "" {
		searchPattern := "%" + escapeLikePattern(strings.ToLower(params.Search)) + "%"
		query = query.Where("LOWER(quiz_title) LIKE ? ESCAPE '\\'", searchPattern)
	}

	if params.Type != "" {
		query = query.Where("quiz_type = ?", params.Type)
	}

	var totalCount int64
	if err := query.Count(&totalCount).Error; err != nil {
		return models.PaginatedAttemptSummaries{}, apperrors.ErrFetchAttemptsFailed
	}

	var attempts []models.QuizAttempt
	result := query.Order(params.GetAttemptOrderBy()).
		Limit(params.Limit).
		Offset(params.Offset).
		Find(&attempts)

	if result.Error != nil {
		return models.PaginatedAttemptSummaries{}, apperrors.ErrFetchAttemptsFailed
	}

	summaries := make([]models.AttemptSummaryResponse, 0, len(attempts))
	for _, attempt := range attempts {
		summaries = append(summaries, models.AttemptSummaryResponse{
			ID:            attempt.ID,
			UserID:        attempt.UserID,
			QuizID:        attempt.QuizID,
			QuizTitle:     attempt.QuizTitle,
			QuizType:      attempt.QuizType,
			AttemptNumber: attempt.AttemptNumber,
			Status:        attempt.Status,
			Score:         attempt.Score,
			CorrectCount:  attempt.CorrectCount,
			TotalCount:    attempt.TotalCount,
			CreatedAt:     attempt.CreatedAt,
			CompletedAt:   attempt.CompletedAt,
		})
	}

	return models.NewPaginatedAttemptSummaries(summaries, params.Limit, params.Offset, int(totalCount)), nil
}

func (s *AttemptService) GetByID(userID uint, id uint) (*models.AttemptResponse, error) {
	var attempt models.QuizAttempt
	result := s.db.Preload("Answers").First(&attempt, id)
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrAttemptNotFound
		}
		return nil, apperrors.ErrFetchAttemptFailed
	}

	if attempt.UserID != userID {
		return nil, apperrors.ErrAttemptNotFound
	}

	response := s.convertToResponse(attempt)
	return &response, nil
}

func (s *AttemptService) convertToResponse(attempt models.QuizAttempt) models.AttemptResponse {
	answers := []models.AttemptAnswerResponse{}

	for _, answer := range attempt.Answers {
		userAnswers := []int{}
		if answer.UserAnswers != "" {
			if err := json.Unmarshal([]byte(answer.UserAnswers), &userAnswers); err != nil {
				s.logger.Warn("Failed to unmarshal user answers",
					zap.Uint("answer_id", answer.ID),
					zap.Error(err))
			}
		}

		correctAnswers := []int{}
		if answer.CorrectAnswers != "" {
			if err := json.Unmarshal([]byte(answer.CorrectAnswers), &correctAnswers); err != nil {
				s.logger.Warn("Failed to unmarshal correct answers",
					zap.Uint("answer_id", answer.ID),
					zap.Error(err))
			}
		}

		options := []string{}
		if answer.Options != "" {
			if err := json.Unmarshal([]byte(answer.Options), &options); err != nil {
				s.logger.Warn("Failed to unmarshal options",
					zap.Uint("answer_id", answer.ID),
					zap.Error(err))
			}
		}

		answers = append(answers, models.AttemptAnswerResponse{
			ID:             answer.ID,
			QuestionID:     answer.QuestionID,
			QuestionText:   answer.QuestionText,
			QuestionType:   answer.QuestionType,
			UserAnswer:     answer.UserAnswer,
			UserAnswers:    userAnswers,
			CorrectAnswer:  answer.CorrectAnswer,
			CorrectAnswers: correctAnswers,
			Options:        options,
			IsCorrect:      answer.IsCorrect,
		})
	}

	return models.AttemptResponse{
		ID:            attempt.ID,
		UserID:        attempt.UserID,
		QuizID:        attempt.QuizID,
		QuizTitle:     attempt.QuizTitle,
		QuizType:      attempt.QuizType,
		AttemptNumber: attempt.AttemptNumber,
		Status:        attempt.Status,
		Score:         attempt.Score,
		CorrectCount:  attempt.CorrectCount,
		TotalCount:    attempt.TotalCount,
		CreatedAt:     attempt.CreatedAt,
		CompletedAt:   attempt.CompletedAt,
		Answers:       answers,
	}
}
