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
// Server-side validation: fetches questions and validates answers
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

		// Fetch questionnaire with questions for validation
		var questionnaire models.Questionnaire
		if err := tx.Preload("Questions").First(&questionnaire, attempt.QuestionnaireID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return apperrors.ErrQuestionnaireNotFound
			}
			return err
		}

		// Build question lookup map
		questionMap := make(map[uint]models.Question)
		for _, q := range questionnaire.Questions {
			questionMap[q.ID] = q
		}

		// Validate each answer and build answer records
		// Track seen question IDs to prevent duplicate submissions inflating score
		seenQuestions := make(map[uint]bool)
		correctCount := 0
		for _, answerReq := range req.Answers {
			// Skip duplicate question submissions
			if seenQuestions[answerReq.QuestionID] {
				s.logger.Warn("Duplicate question submission ignored",
					zap.Uint("question_id", answerReq.QuestionID),
					zap.Uint("attempt_id", attemptID))
				continue
			}
			seenQuestions[answerReq.QuestionID] = true

			question, found := questionMap[answerReq.QuestionID]
			if !found {
				s.logger.Warn("Question not found in questionnaire",
					zap.Uint("question_id", answerReq.QuestionID),
					zap.Uint("questionnaire_id", attempt.QuestionnaireID))
				continue
			}

			// Parse options from question
			var options []string
			if err := json.Unmarshal([]byte(question.Options), &options); err != nil {
				s.logger.Warn("Failed to unmarshal options",
					zap.Uint("question_id", question.ID),
					zap.Error(err))
				options = []string{}
			}

			// Validate answer based on question type
			var isCorrect bool
			var correctAnswer *int
			var correctAnswers []int
			var userAnswersJSON, correctAnswersJSON, optionsJSON string

			if question.QuestionType == models.QuestionTypeMultipleChoice {
				// Parse correct answers from question
				if err := json.Unmarshal([]byte(question.CorrectAnswers), &correctAnswers); err != nil {
					s.logger.Warn("Failed to unmarshal correct answers",
						zap.Uint("question_id", question.ID),
						zap.Error(err))
				}

				// Validate multiple choice answer
				isCorrect = validation.ValidateMultipleChoice(answerReq.UserAnswers, correctAnswers)

				// Marshal for storage
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
				// Single choice - copy to avoid pointer to loop variable
				ca := question.CorrectAnswer
				correctAnswer = &ca

				// Validate single choice answer
				if answerReq.UserAnswer != nil {
					isCorrect = *answerReq.UserAnswer == question.CorrectAnswer
				}
			}

			if isCorrect {
				correctCount++
			}

			// Marshal options for storage
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

		// Calculate score using questionnaire's total question count
		// This ensures accurate scoring even if user skips questions
		totalCount := len(questionnaire.Questions)
		var score int
		if totalCount > 0 {
			score = (correctCount * 100) / totalCount
		}

		// Update attempt with calculated results
		now := time.Now()
		attempt.Status = models.AttemptStatusCompleted
		attempt.Score = score
		attempt.CorrectCount = correctCount
		attempt.TotalCount = totalCount
		attempt.CompletedAt = &now

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
