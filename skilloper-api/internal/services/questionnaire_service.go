package services

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/rand"
	"mime/multipart"
	"strings"
	"sync"
	"time"

	"gorm.io/gorm"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/jsonutil"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

// Package-level RNG for alternative text selection (thread-safe via mutex)
var (
	globalRng     *rand.Rand
	globalRngOnce sync.Once
	globalRngMu   sync.Mutex
)

// getGlobalRng returns the package-level RNG (initialized once)
func getGlobalRng() *rand.Rand {
	globalRngOnce.Do(func() {
		globalRng = rand.New(rand.NewSource(time.Now().UnixNano()))
	})
	return globalRng
}

// randomIntn returns a random int in [0,n) using the global RNG (thread-safe)
func randomIntn(n int) int {
	globalRngMu.Lock()
	defer globalRngMu.Unlock()
	return getGlobalRng().Intn(n)
}

type QuestionnaireService struct {
	db *gorm.DB
}

func NewQuestionnaireService(db *gorm.DB) *QuestionnaireService {
	return &QuestionnaireService{
		db: db,
	}
}

// QuestionnaireSummaryRow represents a questionnaire with question count from a single query
type QuestionnaireSummaryRow struct {
	models.Questionnaire
	QuestionCount int64 `gorm:"column:question_count"`
}

// GetPaginatedSummaries returns paginated questionnaire summaries with search and filter
func (s *QuestionnaireService) GetPaginatedSummaries(params models.PaginationParams) (models.PaginatedQuestionnaireSummaries, error) {
	// Build base query with filters
	baseQuery := s.db.Model(&models.Questionnaire{})

	// Apply search filter (case-insensitive)
	if params.Search != "" {
		searchPattern := "%" + strings.ToLower(params.Search) + "%"
		baseQuery = baseQuery.Where("LOWER(title) LIKE ?", searchPattern)
	}

	// Apply type filter (already validated by handler)
	if params.Type != "" {
		baseQuery = baseQuery.Where("type = ?", params.Type)
	}

	// Get total count (before pagination)
	var totalCount int64
	if err := baseQuery.Count(&totalCount).Error; err != nil {
		return models.PaginatedQuestionnaireSummaries{}, apperrors.ErrFetchQuestionnairesFailed
	}

	// Fetch questionnaires with question counts in a single query using subquery
	var rows []QuestionnaireSummaryRow
	subquery := s.db.Model(&models.Question{}).
		Select("questionnaire_id, COUNT(*) as cnt").
		Group("questionnaire_id")

	result := s.db.Table("questionnaires").
		Select("questionnaires.*, COALESCE(q.cnt, 0) as question_count").
		Joins("LEFT JOIN (?) as q ON questionnaires.id = q.questionnaire_id", subquery)

	// Re-apply filters to the joined query
	if params.Search != "" {
		searchPattern := "%" + strings.ToLower(params.Search) + "%"
		result = result.Where("LOWER(questionnaires.title) LIKE ?", searchPattern)
	}
	if params.Type != "" {
		result = result.Where("questionnaires.type = ?", params.Type)
	}

	// Apply pagination and order (dynamic sort from params)
	result = result.Order(params.GetQuestionnaireOrderBy()).
		Limit(params.Limit).
		Offset(params.Offset).
		Find(&rows)

	if result.Error != nil {
		return models.PaginatedQuestionnaireSummaries{}, apperrors.ErrFetchQuestionnairesFailed
	}

	// Convert to summaries
	summaries := make([]models.QuestionnaireSummary, 0, len(rows))
	for _, row := range rows {
		summaries = append(summaries, models.QuestionnaireSummary{
			ID:            row.ID,
			Title:         row.Title,
			Description:   row.Description,
			Type:          row.Type,
			MaxOptions:    row.MaxOptions,
			CreatedAt:     row.CreatedAt,
			UpdatedAt:     row.UpdatedAt,
			QuestionCount: int(row.QuestionCount),
		})
	}

	return models.NewPaginatedQuestionnaireSummaries(summaries, params.Limit, params.Offset, int(totalCount)), nil
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

	// Validate field lengths (centralized validation for all import paths)
	// Constants defined in models/limits.go
	if len(req.Title) > models.MaxTitleLength {
		return nil, apperrors.NewValidationError("TITLE_TOO_LONG",
			fmt.Sprintf("title exceeds %d character limit", models.MaxTitleLength))
	}
	if len(req.Description) > models.MaxDescriptionLength {
		return nil, apperrors.NewValidationError("DESCRIPTION_TOO_LONG",
			fmt.Sprintf("description exceeds %d character limit", models.MaxDescriptionLength))
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

// MaxImportFileSize is the maximum allowed file size for imports (10MB)
const MaxImportFileSize = 10 * 1024 * 1024

// ImportFromFile imports questionnaires from an uploaded file (JSON or CSV)
// Uses the parser registry to auto-detect format and parse
func (s *QuestionnaireService) ImportFromFile(file *multipart.FileHeader, csvMeta ...CSVMetadata) (*models.QuestionnaireSummary, error) {
	// Check file size before reading
	if file.Size > MaxImportFileSize {
		return nil, apperrors.NewValidationError("FILE_TOO_LARGE", "file exceeds 10MB limit")
	}

	// Open the uploaded file
	src, err := file.Open()
	if err != nil {
		return nil, apperrors.ErrFileOpenFailed
	}
	defer src.Close()

	// Read file content with size limit as safety measure
	fileContent, err := io.ReadAll(io.LimitReader(src, MaxImportFileSize+1))
	if err != nil {
		return nil, apperrors.ErrFileReadFailed
	}
	if int64(len(fileContent)) > MaxImportFileSize {
		return nil, apperrors.NewValidationError("FILE_TOO_LARGE", "file exceeds 10MB limit")
	}

	// Build parser metadata
	metadata := ParserMetadata{
		Filename: file.Filename,
	}
	if len(csvMeta) > 0 {
		metadata.Title = csvMeta[0].Title
		metadata.Description = csvMeta[0].Description
		metadata.Type = csvMeta[0].Type
		metadata.MaxOptions = csvMeta[0].MaxOptions
	}

	// Use parser registry to auto-detect format and parse
	registry := NewParserRegistry()
	req, formatType, err := registry.Parse(fileContent, metadata)
	if err != nil {
		// Return format-specific error codes
		switch formatType {
		case "csv":
			return nil, apperrors.NewValidationError("INVALID_CSV_FORMAT", err.Error())
		case "json":
			// Only use jsonutil for actual JSON syntax errors, not validation errors
			errMsg := err.Error()
			if strings.HasPrefix(errMsg, "invalid JSON:") || strings.HasPrefix(errMsg, "invalid internal format JSON:") {
				errorInfo := jsonutil.ParseJSONError(err, fileContent, file.Filename)
				return nil, apperrors.NewValidationError("INVALID_JSON_FORMAT", errorInfo.Message)
			}
			return nil, apperrors.NewValidationError("INVALID_JSON_FORMAT", errMsg)
		default:
			return nil, apperrors.NewValidationError("INVALID_FILE_FORMAT", err.Error())
		}
	}

	// Use existing Create method to validate and create questionnaire
	questionnaireResponse, err := s.Create(*req)
	if err != nil {
		return nil, err
	}

	// Convert to summary
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

// Helper method to convert database model to response
// Applies alternative text selection for variety, but keeps options in original order
// (frontend handles display shuffling to maintain server-side validation compatibility)
func (s *QuestionnaireService) convertToResponse(q models.Questionnaire) models.QuestionnaireResponse {
	var questions []models.QuestionResponse

	for _, question := range q.Questions {
		var options []string
		if err := json.Unmarshal([]byte(question.Options), &options); err != nil {
			options = []string{} // Use empty slice on parse error
		}

		// Pick alternative question text if available
		questionText := question.QuestionText
		if question.AlternativeQuestions != "" {
			var alternatives []string
			if err := json.Unmarshal([]byte(question.AlternativeQuestions), &alternatives); err == nil && len(alternatives) > 0 {
				allTexts := append([]string{questionText}, alternatives...)
				questionText = allTexts[randomIntn(len(allTexts))]
			}
		}

		// Pick alternative answer text if available (for single choice)
		if question.AlternativeAnswers != "" && question.CorrectAnswer >= 0 && question.CorrectAnswer < len(options) {
			var alternatives []string
			if err := json.Unmarshal([]byte(question.AlternativeAnswers), &alternatives); err == nil && len(alternatives) > 0 {
				allTexts := append([]string{options[question.CorrectAnswer]}, alternatives...)
				options[question.CorrectAnswer] = allTexts[randomIntn(len(allTexts))]
			}
		}

		// Parse correct answers for multiple choice
		var correctAnswers []int
		if question.QuestionType == models.QuestionTypeMultipleChoice && question.CorrectAnswers != "" {
			if err := json.Unmarshal([]byte(question.CorrectAnswers), &correctAnswers); err != nil {
				correctAnswers = []int{} // Use empty slice on parse error
			}
		}

		// Options stay in ORIGINAL order (frontend will shuffle for display)
		questions = append(questions, models.QuestionResponse{
			ID:             question.ID,
			QuestionType:   question.QuestionType,
			Question:       questionText,
			Code:           question.Code,
			Language:       question.Language,
			Options:        options,
			CorrectAnswer:  question.CorrectAnswer,
			CorrectAnswers: correctAnswers,
			Explanation:    question.Explanation,
		})
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
