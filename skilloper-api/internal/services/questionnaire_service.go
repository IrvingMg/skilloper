package services

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"

	"gorm.io/gorm"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/jsonutil"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
	"github.com/irvingmg/skilloper/skilloper-api/internal/shuffle"
)

type QuestionnaireService struct {
	db       *gorm.DB
	shuffler *shuffle.QuestionShuffler
}

func NewQuestionnaireService(db *gorm.DB) *QuestionnaireService {
	return &QuestionnaireService{
		db:       db,
		shuffler: shuffle.New(),
	}
}

// GetAllSummaries returns all questionnaires without questions (for home page)
func (s *QuestionnaireService) GetAllSummaries() ([]models.QuestionnaireSummary, error) {
	var questionnaires []models.Questionnaire
	result := s.db.Find(&questionnaires)
	if result.Error != nil {
		return nil, apperrors.ErrFetchQuestionnairesFailed
	}

	var summaries []models.QuestionnaireSummary
	for _, q := range questionnaires {
		// Count questions for this questionnaire
		var questionCount int64
		result := s.db.Model(&models.Question{}).Where("questionnaire_id = ?", q.ID).Count(&questionCount)
		if result.Error != nil {
			return nil, apperrors.ErrFetchQuestionnairesFailed
		}

		summaries = append(summaries, models.QuestionnaireSummary{
			ID:            q.ID,
			Title:         q.Title,
			Description:   q.Description,
			Type:          q.Type,
			MaxOptions:    q.MaxOptions,
			CreatedAt:     q.CreatedAt,
			UpdatedAt:     q.UpdatedAt,
			QuestionCount: int(questionCount),
		})
	}

	return summaries, nil
}

// GetByID retrieves a questionnaire by ID
func (s *QuestionnaireService) GetByID(id uint) (*models.QuestionnaireResponse, error) {
	var questionnaire models.Questionnaire
	result := s.db.Preload("Questions").First(&questionnaire, id)
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrQuestionnaireNotFound
		}
		return nil, apperrors.ErrFetchQuestionnaireFailed
	}

	response := s.convertToResponse(questionnaire)
	return &response, nil
}

// Create creates a new questionnaire
func (s *QuestionnaireService) Create(req models.CreateQuestionnaireRequest) (*models.QuestionnaireResponse, error) {
	// Validate required fields
	if req.Title == "" {
		return nil, apperrors.ErrQuestionnaireTitleRequired
	}

	// Validate questionnaire type
	if req.Type != "practice" && req.Type != "exam" {
		req.Type = "practice" // Default to practice mode
	}

	// Set default maxOptions if not provided (zero value)
	maxOptions := req.MaxOptions
	if maxOptions == 0 {
		maxOptions = models.DefaultMaxOptions
	}
	// Validate range
	if maxOptions < models.MinOptionsLimit {
		maxOptions = models.MinOptionsLimit
	} else if maxOptions > models.MaxOptionsLimit {
		maxOptions = models.MaxOptionsLimit
	}

	// Create questionnaire
	questionnaire := models.Questionnaire{
		Title:       req.Title,
		Description: req.Description,
		Type:        req.Type,
		MaxOptions:  maxOptions,
	}

	// Create questions
	for i, qReq := range req.Questions {
		if qReq.Question == "" {
			return nil, apperrors.NewValidationError(apperrors.ErrQuestionTextRequired.Code,
				fmt.Sprintf("Question %d is missing required text", i+1))
		}

		// Set default question type
		questionType := qReq.QuestionType
		if questionType == "" {
			questionType = models.QuestionTypeSingleChoice
		}

		// Validate question type
		if questionType != models.QuestionTypeSingleChoice && questionType != models.QuestionTypeMultipleChoice {
			return nil, apperrors.NewValidationError(apperrors.ErrInvalidQuestionType.Code,
				fmt.Sprintf("Question %d has invalid type '%s'. Must be 'single_choice' or 'multiple_choice'", i+1, questionType))
		}

		// Handle options - both single choice and multiple choice need options
		if len(qReq.Options) == 0 {
			return nil, apperrors.NewValidationError(apperrors.ErrQuestionOptionsRequired.Code,
				fmt.Sprintf("Question %d is missing required options", i+1))
		}

		// Validate options don't exceed questionnaire's maxOptions limit
		if len(qReq.Options) > maxOptions {
			return nil, apperrors.NewValidationError(apperrors.ErrTooManyOptions.Code,
				fmt.Sprintf("Question has %d options but questionnaire max_options is %d", len(qReq.Options), maxOptions))
		}

		optionBytes, err := json.Marshal(qReq.Options)
		if err != nil {
			return nil, apperrors.ErrInvalidOptionsFormat
		}
		optionsJSON := string(optionBytes)

		// Marshal new optional fields
		var alternativeQuestionsJSON, alternativeOptionsJSON, alternativeAnswersJSON string

		if len(qReq.AlternativeQuestions) > 0 {
			alternativeQuestions, err := json.Marshal(qReq.AlternativeQuestions)
			if err != nil {
				return nil, apperrors.ErrInvalidOptionsFormat
			}
			alternativeQuestionsJSON = string(alternativeQuestions)
		}

		if len(qReq.AlternativeOptions) > 0 {
			alternativeOptions, err := json.Marshal(qReq.AlternativeOptions)
			if err != nil {
				return nil, apperrors.ErrInvalidOptionsFormat
			}
			alternativeOptionsJSON = string(alternativeOptions)
		}

		if len(qReq.AlternativeAnswers) > 0 {
			alternativeAnswers, err := json.Marshal(qReq.AlternativeAnswers)
			if err != nil {
				return nil, apperrors.ErrInvalidOptionsFormat
			}
			alternativeAnswersJSON = string(alternativeAnswers)
		}

		// Handle correct answers based on question type
		var correctAnswersJSON string
		var finalCorrectAnswer int

		if questionType == models.QuestionTypeMultipleChoice {
			if len(qReq.CorrectAnswers) == 0 {
				return nil, apperrors.NewValidationError(apperrors.ErrMultipleChoiceAnswersRequired.Code,
					fmt.Sprintf("Question %d (multiple_choice) is missing required correct_answers array", i+1))
			}
			// Validate range (already 0-based)
			validCorrectAnswers := []int{}
			for _, answer := range qReq.CorrectAnswers {
				if answer >= 0 && answer < len(qReq.Options) {
					validCorrectAnswers = append(validCorrectAnswers, answer)
				}
			}
			if len(validCorrectAnswers) == 0 {
				return nil, apperrors.NewValidationError(apperrors.ErrInvalidCorrectAnswer.Code,
					fmt.Sprintf("Question %d has invalid correct_answers indices. All indices must be between 0 and %d", i+1, len(qReq.Options)-1))
			}
			correctAnswersBytes, err := json.Marshal(validCorrectAnswers)
			if err != nil {
				return nil, apperrors.ErrInvalidOptionsFormat
			}
			correctAnswersJSON = string(correctAnswersBytes)
		} else {
			// Single choice - validate range (already 0-based)
			if qReq.CorrectAnswer < 0 || qReq.CorrectAnswer >= len(qReq.Options) {
				return nil, apperrors.NewValidationError(apperrors.ErrInvalidCorrectAnswer.Code,
					fmt.Sprintf("Question %d has invalid correctAnswer index %d. Must be between 0 and %d", i+1, qReq.CorrectAnswer, len(qReq.Options)-1))
			}
			finalCorrectAnswer = qReq.CorrectAnswer
		}

		question := models.Question{
			QuestionType:         questionType,
			QuestionText:         qReq.Question,
			AlternativeQuestions: alternativeQuestionsJSON,
			Code:                 qReq.Code,
			Language:             qReq.Language,
			Options:              optionsJSON,
			AlternativeOptions:   alternativeOptionsJSON,
			CorrectAnswer:        finalCorrectAnswer,
			CorrectAnswers:       correctAnswersJSON,
			AlternativeAnswers:   alternativeAnswersJSON,
			Explanation:          qReq.Explanation,
		}
		questionnaire.Questions = append(questionnaire.Questions, question)
	}

	// Save to database
	result := s.db.Create(&questionnaire)
	if result.Error != nil {
		return nil, apperrors.ErrCreateQuestionnaireFailed
	}

	response := s.convertToResponse(questionnaire)
	return &response, nil
}

// Update updates an existing questionnaire
func (s *QuestionnaireService) Update(id uint, req models.CreateQuestionnaireRequest) (*models.QuestionnaireResponse, error) {
	// Validate required fields
	if req.Title == "" {
		return nil, apperrors.ErrQuestionnaireTitleRequired
	}

	// Validate questionnaire type
	if req.Type != "practice" && req.Type != "exam" {
		req.Type = "practice" // Default to practice mode
	}

	// Set default maxOptions if not provided (zero value)
	maxOptions := req.MaxOptions
	if maxOptions == 0 {
		maxOptions = models.DefaultMaxOptions
	}
	// Validate range
	if maxOptions < models.MinOptionsLimit {
		maxOptions = models.MinOptionsLimit
	} else if maxOptions > models.MaxOptionsLimit {
		maxOptions = models.MaxOptionsLimit
	}

	// Find existing questionnaire
	var questionnaire models.Questionnaire
	result := s.db.First(&questionnaire, id)
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrQuestionnaireNotFound
		}
		return nil, apperrors.ErrFetchQuestionnaireFailed
	}

	// Update questionnaire fields
	questionnaire.Title = req.Title
	questionnaire.Description = req.Description
	questionnaire.Type = req.Type
	questionnaire.MaxOptions = maxOptions

	// Validate questions first
	for i, qReq := range req.Questions {
		if qReq.Question == "" {
			return nil, apperrors.NewValidationError(apperrors.ErrQuestionTextRequired.Code,
				fmt.Sprintf("Question %d is missing required text", i+1))
		}

		// Set default question type
		questionType := qReq.QuestionType
		if questionType == "" {
			questionType = models.QuestionTypeSingleChoice
		}

		// Validate question type
		if questionType != models.QuestionTypeSingleChoice && questionType != models.QuestionTypeMultipleChoice {
			return nil, apperrors.NewValidationError(apperrors.ErrInvalidQuestionType.Code,
				fmt.Sprintf("Question %d has invalid type '%s'. Must be 'single_choice' or 'multiple_choice'", i+1, questionType))
		}

		// Handle options - both single choice and multiple choice need options
		if len(qReq.Options) == 0 {
			return nil, apperrors.NewValidationError(apperrors.ErrQuestionOptionsRequired.Code,
				fmt.Sprintf("Question %d is missing required options", i+1))
		}

		// Validate options don't exceed questionnaire's maxOptions limit
		if len(qReq.Options) > maxOptions {
			return nil, apperrors.NewValidationError(apperrors.ErrTooManyOptions.Code,
				fmt.Sprintf("Question has %d options but questionnaire max_options is %d", len(qReq.Options), maxOptions))
		}

		// Validate correct answers based on question type
		if questionType == models.QuestionTypeMultipleChoice {
			if len(qReq.CorrectAnswers) == 0 {
				return nil, apperrors.NewValidationError(apperrors.ErrMultipleChoiceAnswersRequired.Code,
					fmt.Sprintf("Question %d (multiple_choice) is missing required correct_answers array", i+1))
			}
			// Validate range (already 0-based)
			validCorrectAnswers := []int{}
			for _, answer := range qReq.CorrectAnswers {
				if answer >= 0 && answer < len(qReq.Options) {
					validCorrectAnswers = append(validCorrectAnswers, answer)
				}
			}
			if len(validCorrectAnswers) == 0 {
				return nil, apperrors.NewValidationError(apperrors.ErrInvalidCorrectAnswer.Code,
					fmt.Sprintf("Question %d has invalid correct_answers indices. All indices must be between 0 and %d", i+1, len(qReq.Options)-1))
			}
		} else {
			// Single choice - validate range (already 0-based)
			if qReq.CorrectAnswer < 0 || qReq.CorrectAnswer >= len(qReq.Options) {
				return nil, apperrors.NewValidationError(apperrors.ErrInvalidCorrectAnswer.Code,
					fmt.Sprintf("Question %d has invalid correctAnswer index %d. Must be between 0 and %d", i+1, qReq.CorrectAnswer, len(qReq.Options)-1))
			}
		}
	}

	// Delete existing questions
	result = s.db.Where("questionnaire_id = ?", questionnaire.ID).Delete(&models.Question{})
	if result.Error != nil {
		return nil, apperrors.ErrDeleteQuestionsFailed
	}

	// Create new questions
	for _, qReq := range req.Questions {
		// Set default question type
		questionType := qReq.QuestionType
		if questionType == "" {
			questionType = models.QuestionTypeSingleChoice
		}

		optionBytes, err := json.Marshal(qReq.Options)
		if err != nil {
			return nil, apperrors.ErrInvalidOptionsFormat
		}
		optionsJSON := string(optionBytes)

		// Marshal optional fields
		var alternativeQuestionsJSON, alternativeOptionsJSON, alternativeAnswersJSON string
		if len(qReq.AlternativeQuestions) > 0 {
			alternativeQuestions, err := json.Marshal(qReq.AlternativeQuestions)
			if err != nil {
				return nil, apperrors.ErrInvalidOptionsFormat
			}
			alternativeQuestionsJSON = string(alternativeQuestions)
		}
		if len(qReq.AlternativeOptions) > 0 {
			alternativeOptions, err := json.Marshal(qReq.AlternativeOptions)
			if err != nil {
				return nil, apperrors.ErrInvalidOptionsFormat
			}
			alternativeOptionsJSON = string(alternativeOptions)
		}
		if len(qReq.AlternativeAnswers) > 0 {
			alternativeAnswers, err := json.Marshal(qReq.AlternativeAnswers)
			if err != nil {
				return nil, apperrors.ErrInvalidOptionsFormat
			}
			alternativeAnswersJSON = string(alternativeAnswers)
		}

		// Handle correct answers
		var correctAnswersJSON string
		var finalCorrectAnswer int
		if questionType == models.QuestionTypeMultipleChoice {
			correctAnswersBytes, err := json.Marshal(qReq.CorrectAnswers)
			if err != nil {
				return nil, apperrors.ErrInvalidOptionsFormat
			}
			correctAnswersJSON = string(correctAnswersBytes)
		} else {
			finalCorrectAnswer = qReq.CorrectAnswer
		}

		question := models.Question{
			QuestionnaireID:      questionnaire.ID,
			QuestionType:         questionType,
			QuestionText:         qReq.Question,
			AlternativeQuestions: alternativeQuestionsJSON,
			Code:                 qReq.Code,
			Language:             qReq.Language,
			Options:              optionsJSON,
			AlternativeOptions:   alternativeOptionsJSON,
			CorrectAnswer:        finalCorrectAnswer,
			CorrectAnswers:       correctAnswersJSON,
			AlternativeAnswers:   alternativeAnswersJSON,
			Explanation:          qReq.Explanation,
		}
		result = s.db.Create(&question)
		if result.Error != nil {
			return nil, apperrors.ErrCreateQuestionFailed
		}
	}

	// Save questionnaire changes
	result = s.db.Save(&questionnaire)
	if result.Error != nil {
		return nil, apperrors.ErrUpdateQuestionnaireFailed
	}

	// Reload questionnaire with questions
	result = s.db.Preload("Questions").First(&questionnaire, id)
	if result.Error != nil {
		return nil, apperrors.ErrFetchQuestionnaireFailed
	}

	response := s.convertToResponse(questionnaire)
	return &response, nil
}

// Delete deletes a questionnaire by ID
func (s *QuestionnaireService) Delete(id uint) error {
	// Delete questions first (foreign key constraint)
	result := s.db.Where("questionnaire_id = ?", id).Delete(&models.Question{})
	if result.Error != nil {
		return apperrors.ErrDeleteQuestionsFailed
	}

	// Delete questionnaire
	result = s.db.Delete(&models.Questionnaire{}, id)
	if result.Error != nil {
		return apperrors.ErrDeleteQuestionnaireFailed
	}

	if result.RowsAffected == 0 {
		return apperrors.ErrQuestionnaireNotFound
	}

	return nil
}

// ImportFromFile imports questionnaires from an uploaded JSON file
func (s *QuestionnaireService) ImportFromFile(file *multipart.FileHeader) (*models.QuestionnaireSummary, error) {
	// Open the uploaded file
	src, err := file.Open()
	if err != nil {
		return nil, apperrors.ErrFileOpenFailed
	}
	defer src.Close()

	// Read file content
	fileContent, err := io.ReadAll(src)
	if err != nil {
		return nil, apperrors.ErrFileReadFailed
	}

	// Parse JSON content with detailed error information
	var req models.CreateQuestionnaireRequest
	if err := json.Unmarshal(fileContent, &req); err != nil {
		// Use utility function to get detailed error information
		errorInfo := jsonutil.ParseJSONError(err, fileContent, file.Filename)
		return nil, apperrors.NewValidationError("INVALID_JSON_FORMAT", errorInfo.Message)
	}

	// Use existing Create method to validate and create questionnaire
	questionnaireResponse, err := s.Create(req)
	if err != nil {
		return nil, err
	}

	// Convert to summary instead of returning full questionnaire with questions
	summary := &models.QuestionnaireSummary{
		ID:            questionnaireResponse.ID,
		Title:         questionnaireResponse.Title,
		Description:   questionnaireResponse.Description,
		Type:          questionnaireResponse.Type,
		MaxOptions:    questionnaireResponse.MaxOptions,
		CreatedAt:     questionnaireResponse.CreatedAt,
		UpdatedAt:     questionnaireResponse.UpdatedAt,
		QuestionCount: len(questionnaireResponse.Questions),
	}

	return summary, nil
}

// Helper method to convert database model to response with shuffling
func (s *QuestionnaireService) convertToResponse(q models.Questionnaire) models.QuestionnaireResponse {
	var questions []models.QuestionResponse

	// Use shuffling for questions (shuffles options within each question, not question order)
	shuffledQuestions, err := s.shuffler.ShuffleQuestions(q.Questions)
	if err != nil {
		// If shuffling fails, fall back to regular conversion
		for _, question := range q.Questions {
			var options []string
			json.Unmarshal([]byte(question.Options), &options)

			questions = append(questions, models.QuestionResponse{
				ID:            question.ID,
				Question:      question.QuestionText,
				Code:          question.Code,
				Language:      question.Language,
				Options:       options,
				CorrectAnswer: question.CorrectAnswer,
				Explanation:   question.Explanation,
			})
		}
	} else {
		// Use shuffled questions directly
		questions = shuffledQuestions
	}

	return models.QuestionnaireResponse{
		ID:          q.ID,
		Title:       q.Title,
		Description: q.Description,
		Type:        q.Type,
		MaxOptions:  q.MaxOptions,
		CreatedAt:   q.CreatedAt,
		UpdatedAt:   q.UpdatedAt,
		Questions:   questions,
	}
}
