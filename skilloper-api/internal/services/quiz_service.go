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
	globalRng   *rand.Rand
	globalRngMu sync.Mutex
)

// init initializes the global RNG at package load time
func init() {
	globalRng = rand.New(rand.NewSource(time.Now().UnixNano()))
}

// randomIntn returns a random int in [0,n) using the global RNG (thread-safe)
func randomIntn(n int) int {
	globalRngMu.Lock()
	defer globalRngMu.Unlock()
	return globalRng.Intn(n)
}

type QuizService struct {
	db *gorm.DB
}

func NewQuizService(db *gorm.DB) *QuizService {
	return &QuizService{
		db: db,
	}
}

// QuizSummaryRow represents a quiz with question count from a single query
type QuizSummaryRow struct {
	models.Quiz
	QuestionCount int64 `gorm:"column:question_count"`
}

// escapeLikePattern escapes SQL LIKE special characters (%, _) in search terms
func escapeLikePattern(s string) string {
	s = strings.ReplaceAll(s, "%", "\\%")
	s = strings.ReplaceAll(s, "_", "\\_")
	return s
}

// GetPaginatedSummaries returns paginated quiz summaries with search and filter
func (s *QuizService) GetPaginatedSummaries(params models.PaginationParams) (models.PaginatedQuizSummaries, error) {
	// Build base query with filters
	baseQuery := s.db.Model(&models.Quiz{})

	// Apply search filter (case-insensitive, escape LIKE wildcards)
	if params.Search != "" {
		searchPattern := "%" + escapeLikePattern(strings.ToLower(params.Search)) + "%"
		baseQuery = baseQuery.Where("LOWER(title) LIKE ? ESCAPE '\\'", searchPattern)
	}

	// Apply type filter (already validated by handler)
	if params.Type != "" {
		baseQuery = baseQuery.Where("type = ?", params.Type)
	}

	// Get total count (before pagination)
	var totalCount int64
	if err := baseQuery.Count(&totalCount).Error; err != nil {
		return models.PaginatedQuizSummaries{}, apperrors.ErrFetchQuizzesFailed
	}

	// Fetch quizzes with question counts in a single query using subquery
	var rows []QuizSummaryRow
	subquery := s.db.Model(&models.Question{}).
		Select("quiz_id, COUNT(*) as cnt").
		Group("quiz_id")

	result := s.db.Table("quizzes").
		Select("quizzes.*, COALESCE(q.cnt, 0) as question_count").
		Joins("LEFT JOIN (?) as q ON quizzes.id = q.quiz_id", subquery)

	// Re-apply filters to the joined query
	if params.Search != "" {
		searchPattern := "%" + escapeLikePattern(strings.ToLower(params.Search)) + "%"
		result = result.Where("LOWER(quizzes.title) LIKE ? ESCAPE '\\'", searchPattern)
	}
	if params.Type != "" {
		result = result.Where("quizzes.type = ?", params.Type)
	}

	// Apply pagination and order (dynamic sort from params)
	result = result.Order(params.GetQuizOrderBy()).
		Limit(params.Limit).
		Offset(params.Offset).
		Find(&rows)

	if result.Error != nil {
		return models.PaginatedQuizSummaries{}, apperrors.ErrFetchQuizzesFailed
	}

	// Convert to summaries
	summaries := make([]models.QuizSummary, 0, len(rows))
	for _, row := range rows {
		summaries = append(summaries, models.QuizSummary{
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

	return models.NewPaginatedQuizSummaries(summaries, params.Limit, params.Offset, int(totalCount)), nil
}

// GetByID retrieves a quiz by ID
func (s *QuizService) GetByID(id uint) (*models.QuizResponse, error) {
	var quiz models.Quiz
	result := s.db.Preload("Questions").First(&quiz, id)
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrQuizNotFound
		}
		return nil, apperrors.ErrFetchQuizFailed
	}

	response := s.convertToResponse(quiz)
	return &response, nil
}

// GetByIDWithAnswers retrieves a quiz by ID including correct answers (for edit mode)
func (s *QuizService) GetByIDWithAnswers(id uint) (*models.QuizResponseWithAnswers, error) {
	var quiz models.Quiz
	result := s.db.Preload("Questions").First(&quiz, id)
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrQuizNotFound
		}
		return nil, apperrors.ErrFetchQuizFailed
	}

	response := s.convertToResponseWithAnswers(quiz)
	return &response, nil
}

// Create creates a new quiz
func (s *QuizService) Create(req models.CreateQuizRequest) (*models.QuizResponse, error) {
	// Validate required fields
	if req.Title == "" {
		return nil, apperrors.ErrQuizTitleRequired
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

	// Validate quiz type
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

	// Validate at least one question
	if len(req.Questions) == 0 {
		return nil, apperrors.NewValidationError("NO_QUESTIONS",
			"quiz must have at least one question")
	}

	// Create quiz
	quiz := models.Quiz{
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
		if len(qReq.Options) < models.MinOptionsLimit {
			return nil, apperrors.NewValidationError(apperrors.ErrQuestionOptionsRequired.Code,
				fmt.Sprintf("Question %d requires at least %d options", i+1, models.MinOptionsLimit))
		}

		// Validate options don't exceed quiz's maxOptions limit
		if len(qReq.Options) > maxOptions {
			return nil, apperrors.NewValidationError(apperrors.ErrTooManyOptions.Code,
				fmt.Sprintf("Question has %d options but quiz max_options is %d", len(qReq.Options), maxOptions))
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
			// Validate range and check for duplicates (already 0-based)
			validCorrectAnswers := []int{}
			seenAnswers := make(map[int]bool)
			for _, answer := range qReq.CorrectAnswers {
				if seenAnswers[answer] {
					return nil, apperrors.NewValidationError("DUPLICATE_ANSWER",
						fmt.Sprintf("Question %d has duplicate correct answer index: %d", i+1, answer))
				}
				seenAnswers[answer] = true
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
		quiz.Questions = append(quiz.Questions, question)
	}

	// Save to database
	result := s.db.Create(&quiz)
	if result.Error != nil {
		return nil, apperrors.ErrCreateQuizFailed
	}

	response := s.convertToResponse(quiz)
	return &response, nil
}

// Update updates an existing quiz
func (s *QuizService) Update(id uint, req models.CreateQuizRequest) (*models.QuizResponse, error) {
	// Validate required fields
	if req.Title == "" {
		return nil, apperrors.ErrQuizTitleRequired
	}

	// Validate quiz type
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

	// Validate at least one question
	if len(req.Questions) == 0 {
		return nil, apperrors.NewValidationError("NO_QUESTIONS",
			"quiz must have at least one question")
	}

	// Pre-validate all questions and build validated data before transaction
	type validatedQuestion struct {
		questionType             string
		optionsJSON              string
		alternativeQuestionsJSON string
		alternativeOptionsJSON   string
		alternativeAnswersJSON   string
		correctAnswersJSON       string
		finalCorrectAnswer       int
		qReq                     models.QuestionRequest
	}
	validatedQuestions := make([]validatedQuestion, 0, len(req.Questions))

	for i, qReq := range req.Questions {
		if qReq.Question == "" {
			return nil, apperrors.NewValidationError(apperrors.ErrQuestionTextRequired.Code,
				fmt.Sprintf("Question %d is missing required text", i+1))
		}

		questionType := qReq.QuestionType
		if questionType == "" {
			questionType = models.QuestionTypeSingleChoice
		}

		if questionType != models.QuestionTypeSingleChoice && questionType != models.QuestionTypeMultipleChoice {
			return nil, apperrors.NewValidationError(apperrors.ErrInvalidQuestionType.Code,
				fmt.Sprintf("Question %d has invalid type '%s'. Must be 'single_choice' or 'multiple_choice'", i+1, questionType))
		}

		if len(qReq.Options) < models.MinOptionsLimit {
			return nil, apperrors.NewValidationError(apperrors.ErrQuestionOptionsRequired.Code,
				fmt.Sprintf("Question %d requires at least %d options", i+1, models.MinOptionsLimit))
		}

		if len(qReq.Options) > maxOptions {
			return nil, apperrors.NewValidationError(apperrors.ErrTooManyOptions.Code,
				fmt.Sprintf("Question has %d options but quiz max_options is %d", len(qReq.Options), maxOptions))
		}

		optionBytes, err := json.Marshal(qReq.Options)
		if err != nil {
			return nil, apperrors.ErrInvalidOptionsFormat
		}

		var alternativeQuestionsJSON, alternativeOptionsJSON, alternativeAnswersJSON string
		if len(qReq.AlternativeQuestions) > 0 {
			b, err := json.Marshal(qReq.AlternativeQuestions)
			if err != nil {
				return nil, apperrors.ErrInvalidOptionsFormat
			}
			alternativeQuestionsJSON = string(b)
		}
		if len(qReq.AlternativeOptions) > 0 {
			b, err := json.Marshal(qReq.AlternativeOptions)
			if err != nil {
				return nil, apperrors.ErrInvalidOptionsFormat
			}
			alternativeOptionsJSON = string(b)
		}
		if len(qReq.AlternativeAnswers) > 0 {
			b, err := json.Marshal(qReq.AlternativeAnswers)
			if err != nil {
				return nil, apperrors.ErrInvalidOptionsFormat
			}
			alternativeAnswersJSON = string(b)
		}

		var correctAnswersJSON string
		var finalCorrectAnswer int

		if questionType == models.QuestionTypeMultipleChoice {
			if len(qReq.CorrectAnswers) == 0 {
				return nil, apperrors.NewValidationError(apperrors.ErrMultipleChoiceAnswersRequired.Code,
					fmt.Sprintf("Question %d (multiple_choice) is missing required correct_answers array", i+1))
			}
			// Validate range and check for duplicates
			validCorrectAnswers := []int{}
			seenAnswers := make(map[int]bool)
			for _, answer := range qReq.CorrectAnswers {
				if seenAnswers[answer] {
					return nil, apperrors.NewValidationError("DUPLICATE_ANSWER",
						fmt.Sprintf("Question %d has duplicate correct answer index: %d", i+1, answer))
				}
				seenAnswers[answer] = true
				if answer >= 0 && answer < len(qReq.Options) {
					validCorrectAnswers = append(validCorrectAnswers, answer)
				}
			}
			if len(validCorrectAnswers) == 0 {
				return nil, apperrors.NewValidationError(apperrors.ErrInvalidCorrectAnswer.Code,
					fmt.Sprintf("Question %d has invalid correct_answers indices. All indices must be between 0 and %d", i+1, len(qReq.Options)-1))
			}
			// Use filtered valid answers, not original
			correctAnswersBytes, err := json.Marshal(validCorrectAnswers)
			if err != nil {
				return nil, apperrors.ErrInvalidOptionsFormat
			}
			correctAnswersJSON = string(correctAnswersBytes)
		} else {
			if qReq.CorrectAnswer < 0 || qReq.CorrectAnswer >= len(qReq.Options) {
				return nil, apperrors.NewValidationError(apperrors.ErrInvalidCorrectAnswer.Code,
					fmt.Sprintf("Question %d has invalid correctAnswer index %d. Must be between 0 and %d", i+1, qReq.CorrectAnswer, len(qReq.Options)-1))
			}
			finalCorrectAnswer = qReq.CorrectAnswer
		}

		validatedQuestions = append(validatedQuestions, validatedQuestion{
			questionType:             questionType,
			optionsJSON:              string(optionBytes),
			alternativeQuestionsJSON: alternativeQuestionsJSON,
			alternativeOptionsJSON:   alternativeOptionsJSON,
			alternativeAnswersJSON:   alternativeAnswersJSON,
			correctAnswersJSON:       correctAnswersJSON,
			finalCorrectAnswer:       finalCorrectAnswer,
			qReq:                     qReq,
		})
	}

	// Use transaction to ensure atomicity - either all changes succeed or none
	var quiz models.Quiz
	err := s.db.Transaction(func(tx *gorm.DB) error {
		// Find existing quiz
		if err := tx.First(&quiz, id).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return apperrors.ErrQuizNotFound
			}
			return apperrors.ErrFetchQuizFailed
		}

		// Update quiz fields
		quiz.Title = req.Title
		quiz.Description = req.Description
		quiz.Type = req.Type
		quiz.MaxOptions = maxOptions

		// Delete existing questions
		if err := tx.Where("quiz_id = ?", quiz.ID).Delete(&models.Question{}).Error; err != nil {
			return apperrors.ErrDeleteQuestionsFailed
		}

		// Create new questions
		for _, vq := range validatedQuestions {
			question := models.Question{
				QuizID:               quiz.ID,
				QuestionType:         vq.questionType,
				QuestionText:         vq.qReq.Question,
				AlternativeQuestions: vq.alternativeQuestionsJSON,
				Code:                 vq.qReq.Code,
				Language:             vq.qReq.Language,
				Options:              vq.optionsJSON,
				AlternativeOptions:   vq.alternativeOptionsJSON,
				CorrectAnswer:        vq.finalCorrectAnswer,
				CorrectAnswers:       vq.correctAnswersJSON,
				AlternativeAnswers:   vq.alternativeAnswersJSON,
				Explanation:          vq.qReq.Explanation,
			}
			if err := tx.Create(&question).Error; err != nil {
				return apperrors.ErrCreateQuestionFailed
			}
		}

		// Save quiz changes
		if err := tx.Save(&quiz).Error; err != nil {
			return apperrors.ErrUpdateQuizFailed
		}

		// Reload quiz with questions
		if err := tx.Preload("Questions").First(&quiz, id).Error; err != nil {
			return apperrors.ErrFetchQuizFailed
		}

		return nil
	})

	if err != nil {
		var appErr *apperrors.AppError
		if errors.As(err, &appErr) {
			return nil, appErr
		}
		return nil, apperrors.ErrUpdateQuizFailed
	}

	response := s.convertToResponse(quiz)
	return &response, nil
}

// Delete deletes a quiz by ID
func (s *QuizService) Delete(id uint) error {
	// Delete questions first (foreign key constraint)
	result := s.db.Where("quiz_id = ?", id).Delete(&models.Question{})
	if result.Error != nil {
		return apperrors.ErrDeleteQuestionsFailed
	}

	// Delete quiz
	result = s.db.Delete(&models.Quiz{}, id)
	if result.Error != nil {
		return apperrors.ErrDeleteQuizFailed
	}

	if result.RowsAffected == 0 {
		return apperrors.ErrQuizNotFound
	}

	return nil
}

// MaxImportFileSize is the maximum allowed file size for imports (10MB)
const MaxImportFileSize = 10 * 1024 * 1024

// ImportFromFile imports quizzes from an uploaded file (JSON or CSV)
// Uses the parser registry to auto-detect format and parse
func (s *QuizService) ImportFromFile(file *multipart.FileHeader, csvMeta ...CSVMetadata) (*models.QuizSummary, error) {
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
	fileContent, err := io.ReadAll(io.LimitReader(src, MaxImportFileSize))
	if err != nil {
		return nil, apperrors.ErrFileReadFailed
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

	// Use existing Create method to validate and create quiz
	quizResponse, err := s.Create(*req)
	if err != nil {
		return nil, err
	}

	// Convert to summary
	summary := &models.QuizSummary{
		ID:            quizResponse.ID,
		Title:         quizResponse.Title,
		Description:   quizResponse.Description,
		Type:          quizResponse.Type,
		MaxOptions:    quizResponse.MaxOptions,
		CreatedAt:     quizResponse.CreatedAt,
		UpdatedAt:     quizResponse.UpdatedAt,
		QuestionCount: len(quizResponse.Questions),
	}

	return summary, nil
}

// parseOptionsJSON safely parses the options JSON string, returning empty slice on error
func parseOptionsJSON(optionsJSON string) []string {
	if optionsJSON == "" {
		return []string{}
	}
	var options []string
	if err := json.Unmarshal([]byte(optionsJSON), &options); err != nil {
		return []string{}
	}
	return options
}

// parseCorrectAnswersJSON safely parses the correct_answers JSON string for multiple choice
func parseCorrectAnswersJSON(answersJSON string) []int {
	if answersJSON == "" {
		return []int{}
	}
	var answers []int
	if err := json.Unmarshal([]byte(answersJSON), &answers); err != nil {
		return []int{}
	}
	return answers
}

// parseStringArrayJSON safely parses a JSON string array
func parseStringArrayJSON(jsonStr string) []string {
	if jsonStr == "" {
		return nil
	}
	var result []string
	if err := json.Unmarshal([]byte(jsonStr), &result); err != nil {
		return nil
	}
	return result
}

// Helper method to convert database model to response
// Applies alternative text selection for variety, but keeps options in original order
// (frontend handles display shuffling to maintain server-side validation compatibility)
func (s *QuizService) convertToResponse(q models.Quiz) models.QuizResponse {
	var questions []models.QuestionResponse

	for _, question := range q.Questions {
		options := parseOptionsJSON(question.Options)

		// Pick alternative question text if available
		questionText := question.QuestionText
		if alternatives := parseStringArrayJSON(question.AlternativeQuestions); len(alternatives) > 0 {
			allTexts := append([]string{questionText}, alternatives...)
			questionText = allTexts[randomIntn(len(allTexts))]
		}

		// Pick alternative answer text if available (for single choice)
		if alternatives := parseStringArrayJSON(question.AlternativeAnswers); len(alternatives) > 0 {
			if len(options) > 0 && question.CorrectAnswer >= 0 && question.CorrectAnswer < len(options) {
				allTexts := append([]string{options[question.CorrectAnswer]}, alternatives...)
				options[question.CorrectAnswer] = allTexts[randomIntn(len(allTexts))]
			}
		}

		// Parse correct answers for multiple choice (always use empty slice, not nil)
		correctAnswers := []int{}
		if question.QuestionType == models.QuestionTypeMultipleChoice {
			correctAnswers = parseCorrectAnswersJSON(question.CorrectAnswers)
		}

		// Options stay in ORIGINAL order (frontend will shuffle for display)
		qr := models.QuestionResponse{}
		qr.ID = question.ID
		qr.QuestionType = question.QuestionType
		qr.Question = questionText
		qr.Code = question.Code
		qr.Language = question.Language
		qr.Options = options
		qr.Explanation = question.Explanation
		qr.CorrectAnswer = question.CorrectAnswer
		qr.CorrectAnswers = correctAnswers
		questions = append(questions, qr)
	}

	resp := models.QuizResponse{}
	resp.ID = q.ID
	resp.Title = q.Title
	resp.Description = q.Description
	resp.Type = q.Type
	resp.MaxOptions = q.MaxOptions
	resp.CreatedAt = q.CreatedAt
	resp.UpdatedAt = q.UpdatedAt
	resp.Questions = questions
	return resp
}

// convertToResponseWithAnswers converts database model to response including correct answers
// Used for edit mode - does NOT apply alternative text selection to preserve original data
func (s *QuizService) convertToResponseWithAnswers(q models.Quiz) models.QuizResponseWithAnswers {
	var questions []models.QuestionResponseWithAnswers

	for _, question := range q.Questions {
		options := parseOptionsJSON(question.Options)

		// Parse correct answers for multiple choice (always use empty slice, not nil)
		correctAnswers := []int{}
		if question.QuestionType == models.QuestionTypeMultipleChoice {
			correctAnswers = parseCorrectAnswersJSON(question.CorrectAnswers)
		}

		qr := models.QuestionResponseWithAnswers{}
		qr.ID = question.ID
		qr.QuestionType = question.QuestionType
		qr.Question = question.QuestionText
		qr.Code = question.Code
		qr.Language = question.Language
		qr.Options = options
		qr.Explanation = question.Explanation
		qr.CorrectAnswer = question.CorrectAnswer
		qr.CorrectAnswers = correctAnswers
		questions = append(questions, qr)
	}

	resp := models.QuizResponseWithAnswers{}
	resp.ID = q.ID
	resp.Title = q.Title
	resp.Description = q.Description
	resp.Type = q.Type
	resp.MaxOptions = q.MaxOptions
	resp.CreatedAt = q.CreatedAt
	resp.UpdatedAt = q.UpdatedAt
	resp.Questions = questions
	return resp
}
