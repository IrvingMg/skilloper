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

// Start creates a new in-progress quiz attempt
func (s *AttemptService) Start(req models.StartAttemptRequest) (*models.AttemptResponse, error) {
	// Validate required fields
	if req.DeviceID == "" {
		return nil, apperrors.ErrDeviceIDRequired
	}

	if req.QuestionnaireID == 0 {
		return nil, apperrors.NewValidationError(apperrors.ErrInvalidAttemptData.Code,
			"questionnaire ID is required")
	}

	if req.QuestionnaireTitle == "" {
		return nil, apperrors.NewValidationError(apperrors.ErrInvalidAttemptData.Code,
			"questionnaire title is required")
	}

	var attempt models.QuizAttempt

	// Use transaction to ensure atomic attempt number calculation
	err := s.db.Transaction(func(tx *gorm.DB) error {
		// Calculate attempt number within transaction (count of existing attempts + 1)
		var existingCount int64
		if err := tx.Model(&models.QuizAttempt{}).
			Where("device_id = ? AND questionnaire_id = ?", req.DeviceID, req.QuestionnaireID).
			Count(&existingCount).Error; err != nil {
			return err
		}
		attemptNumber := int(existingCount) + 1

		// Create attempt with in_progress status
		attempt = models.QuizAttempt{
			DeviceID:           req.DeviceID,
			QuestionnaireID:    req.QuestionnaireID,
			QuestionnaireTitle: req.QuestionnaireTitle,
			QuestionnaireType:  req.QuestionnaireType,
			AttemptNumber:      attemptNumber,
			Status:             models.AttemptStatusInProgress,
			TotalCount:         req.TotalCount,
		}

		// Save to database within transaction
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

	// Convert to response
	response := s.convertToResponse(attempt)
	return &response, nil
}

// Complete updates an in-progress attempt with final results
func (s *AttemptService) Complete(attemptID uint, req models.CompleteAttemptRequest) (*models.AttemptResponse, error) {
	var attempt models.QuizAttempt

	err := s.db.Transaction(func(tx *gorm.DB) error {
		// Find the attempt
		if err := tx.First(&attempt, attemptID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return apperrors.ErrAttemptNotFound
			}
			return err
		}

		// Verify it's still in progress
		if attempt.Status != models.AttemptStatusInProgress {
			return apperrors.NewValidationError(apperrors.ErrInvalidAttemptData.Code,
				"attempt is already completed")
		}

		// Update attempt with results
		now := time.Now()
		attempt.Status = models.AttemptStatusCompleted
		attempt.Score = req.Score
		attempt.CorrectCount = req.CorrectCount
		attempt.TotalCount = req.TotalCount
		attempt.CompletedAt = &now

		// Build answers
		for _, answerReq := range req.Answers {
			// Marshal user answers for multiple choice
			var userAnswersJSON string
			if len(answerReq.UserAnswers) > 0 {
				userAnswersBytes, err := json.Marshal(answerReq.UserAnswers)
				if err != nil {
					return apperrors.ErrInvalidAttemptData
				}
				userAnswersJSON = string(userAnswersBytes)
			}

			// Marshal correct answers for multiple choice
			var correctAnswersJSON string
			if len(answerReq.CorrectAnswers) > 0 {
				correctAnswersBytes, err := json.Marshal(answerReq.CorrectAnswers)
				if err != nil {
					return apperrors.ErrInvalidAttemptData
				}
				correctAnswersJSON = string(correctAnswersBytes)
			}

			// Marshal options
			var optionsJSON string
			if len(answerReq.Options) > 0 {
				optionsBytes, err := json.Marshal(answerReq.Options)
				if err != nil {
					return apperrors.ErrInvalidAttemptData
				}
				optionsJSON = string(optionsBytes)
			}

			answer := models.AttemptAnswer{
				AttemptID:      attemptID,
				QuestionID:     answerReq.QuestionID,
				QuestionText:   answerReq.QuestionText,
				QuestionType:   answerReq.QuestionType,
				UserAnswer:     answerReq.UserAnswer,
				UserAnswers:    userAnswersJSON,
				CorrectAnswer:  answerReq.CorrectAnswer,
				CorrectAnswers: correctAnswersJSON,
				Options:        optionsJSON,
				IsCorrect:      answerReq.IsCorrect,
			}
			attempt.Answers = append(attempt.Answers, answer)
		}

		// Save attempt (skip auto-saving Answers to control insertion ourselves)
		if err := tx.Omit("Answers").Save(&attempt).Error; err != nil {
			return err
		}

		// Save answers
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

	// Convert to response
	response := s.convertToResponse(attempt)
	return &response, nil
}

// GetPaginatedByDeviceID returns paginated attempts for a device with search and filter
func (s *AttemptService) GetPaginatedByDeviceID(deviceID string, params models.PaginationParams) (models.PaginatedAttemptSummaries, error) {
	if deviceID == "" {
		return models.PaginatedAttemptSummaries{}, apperrors.ErrDeviceIDRequired
	}

	// Build query with filters
	query := s.db.Model(&models.QuizAttempt{}).Where("device_id = ?", deviceID)

	// Apply search filter (case-insensitive on questionnaire_title)
	if params.Search != "" {
		searchPattern := "%" + strings.ToLower(params.Search) + "%"
		query = query.Where("LOWER(questionnaire_title) LIKE ?", searchPattern)
	}

	// Apply type filter (already validated by handler)
	if params.Type != "" {
		query = query.Where("questionnaire_type = ?", params.Type)
	}

	// Get total count
	var totalCount int64
	if err := query.Count(&totalCount).Error; err != nil {
		return models.PaginatedAttemptSummaries{}, apperrors.ErrFetchAttemptsFailed
	}

	// Apply pagination and fetch
	var attempts []models.QuizAttempt
	result := query.Order("created_at DESC").
		Limit(params.Limit).
		Offset(params.Offset).
		Find(&attempts)

	if result.Error != nil {
		return models.PaginatedAttemptSummaries{}, apperrors.ErrFetchAttemptsFailed
	}

	// Convert to summaries
	summaries := make([]models.AttemptSummaryResponse, 0, len(attempts))
	for _, attempt := range attempts {
		summaries = append(summaries, models.AttemptSummaryResponse{
			ID:                 attempt.ID,
			DeviceID:           attempt.DeviceID,
			QuestionnaireID:    attempt.QuestionnaireID,
			QuestionnaireTitle: attempt.QuestionnaireTitle,
			QuestionnaireType:  attempt.QuestionnaireType,
			AttemptNumber:      attempt.AttemptNumber,
			Status:             attempt.Status,
			Score:              attempt.Score,
			CorrectCount:       attempt.CorrectCount,
			TotalCount:         attempt.TotalCount,
			CreatedAt:          attempt.CreatedAt,
			CompletedAt:        attempt.CompletedAt,
		})
	}

	return models.NewPaginatedAttemptSummaries(summaries, params.Limit, params.Offset, int(totalCount)), nil
}

// GetByID returns a single attempt with all answers
func (s *AttemptService) GetByID(id uint) (*models.AttemptResponse, error) {
	var attempt models.QuizAttempt
	result := s.db.Preload("Answers").First(&attempt, id)
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrAttemptNotFound
		}
		return nil, apperrors.ErrFetchAttemptFailed
	}

	response := s.convertToResponse(attempt)
	return &response, nil
}

// convertToResponse converts database model to response DTO
func (s *AttemptService) convertToResponse(attempt models.QuizAttempt) models.AttemptResponse {
	var answers []models.AttemptAnswerResponse

	for _, answer := range attempt.Answers {
		// Unmarshal user answers
		var userAnswers []int
		if answer.UserAnswers != "" {
			if err := json.Unmarshal([]byte(answer.UserAnswers), &userAnswers); err != nil {
				s.logger.Warn("Failed to unmarshal user answers",
					zap.Uint("answer_id", answer.ID),
					zap.Error(err))
			}
		}

		// Unmarshal correct answers
		var correctAnswers []int
		if answer.CorrectAnswers != "" {
			if err := json.Unmarshal([]byte(answer.CorrectAnswers), &correctAnswers); err != nil {
				s.logger.Warn("Failed to unmarshal correct answers",
					zap.Uint("answer_id", answer.ID),
					zap.Error(err))
			}
		}

		// Unmarshal options
		var options []string
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
		ID:                 attempt.ID,
		DeviceID:           attempt.DeviceID,
		QuestionnaireID:    attempt.QuestionnaireID,
		QuestionnaireTitle: attempt.QuestionnaireTitle,
		QuestionnaireType:  attempt.QuestionnaireType,
		AttemptNumber:      attempt.AttemptNumber,
		Status:             attempt.Status,
		Score:              attempt.Score,
		CorrectCount:       attempt.CorrectCount,
		TotalCount:         attempt.TotalCount,
		CreatedAt:          attempt.CreatedAt,
		CompletedAt:        attempt.CompletedAt,
		Answers:            answers,
	}
}
