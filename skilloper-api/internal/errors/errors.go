package errors

import "fmt"

// ErrorType represents the type of error
type ErrorType string

const (
	// Validation errors
	ErrTypeValidation ErrorType = "validation"
	// Not found errors
	ErrTypeNotFound ErrorType = "not_found"
	// Internal server errors
	ErrTypeInternal ErrorType = "internal"
	// Database errors
	ErrTypeDatabase ErrorType = "database"
)

// AppError represents an application-specific error
type AppError struct {
	Type    ErrorType
	Code    string
	Message string
	Cause   error
}

func (e *AppError) Error() string {
	if e.Cause != nil {
		return fmt.Sprintf("%s: %s (caused by: %v)", e.Code, e.Message, e.Cause)
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func (e *AppError) Unwrap() error {
	return e.Cause
}

// Is checks if the error matches the target error
func (e *AppError) Is(target error) bool {
	if t, ok := target.(*AppError); ok {
		return e.Code == t.Code
	}
	return false
}

// Predefined error variables for common cases
var (
	// Questionnaire errors
	ErrQuestionnaireNotFound = &AppError{
		Type:    ErrTypeNotFound,
		Code:    "QUESTIONNAIRE_NOT_FOUND",
		Message: "questionnaire not found",
	}

	ErrQuestionnaireTitleRequired = &AppError{
		Type:    ErrTypeValidation,
		Code:    "QUESTIONNAIRE_TITLE_REQUIRED",
		Message: "title is required",
	}

	ErrInvalidOptionsFormat = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_OPTIONS_FORMAT",
		Message: "invalid options format",
	}

	ErrInvalidQuestionnaireID = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_QUESTIONNAIRE_ID",
		Message: "invalid questionnaire ID",
	}

	ErrInvalidJSONFormat = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_JSON_FORMAT",
		Message: "invalid JSON format",
	}

	ErrFileRequired = &AppError{
		Type:    ErrTypeValidation,
		Code:    "FILE_REQUIRED",
		Message: "file is required for import",
	}

	ErrFileOpenFailed = &AppError{
		Type:    ErrTypeValidation,
		Code:    "FILE_OPEN_FAILED",
		Message: "failed to open uploaded file",
	}

	ErrFileReadFailed = &AppError{
		Type:    ErrTypeValidation,
		Code:    "FILE_READ_FAILED",
		Message: "failed to read uploaded file",
	}

	// Question validation errors
	ErrQuestionTextRequired = &AppError{
		Type:    ErrTypeValidation,
		Code:    "QUESTION_TEXT_REQUIRED",
		Message: "question text is required",
	}

	ErrInvalidQuestionType = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_QUESTION_TYPE",
		Message: "invalid question type",
	}

	ErrQuestionOptionsRequired = &AppError{
		Type:    ErrTypeValidation,
		Code:    "QUESTION_OPTIONS_REQUIRED",
		Message: "question options are required",
	}

	ErrTooManyOptions = &AppError{
		Type:    ErrTypeValidation,
		Code:    "TOO_MANY_OPTIONS",
		Message: "too many options for question",
	}

	ErrMultipleChoiceAnswersRequired = &AppError{
		Type:    ErrTypeValidation,
		Code:    "MULTIPLE_CHOICE_ANSWERS_REQUIRED",
		Message: "multiple choice questions require correct answers",
	}

	ErrInvalidCorrectAnswer = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_CORRECT_ANSWER",
		Message: "invalid correct answer",
	}

	// Database operation errors
	ErrFetchQuestionnairesFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "FETCH_QUESTIONNAIRES_FAILED",
		Message: "failed to fetch questionnaires",
	}

	ErrFetchQuestionnaireFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "FETCH_QUESTIONNAIRE_FAILED",
		Message: "failed to fetch questionnaire",
	}

	ErrCreateQuestionnaireFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "CREATE_QUESTIONNAIRE_FAILED",
		Message: "failed to create questionnaire",
	}

	ErrCreateQuestionFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "CREATE_QUESTION_FAILED",
		Message: "failed to create question",
	}

	ErrUpdateQuestionnaireFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "UPDATE_QUESTIONNAIRE_FAILED",
		Message: "failed to update questionnaire",
	}

	ErrDeleteQuestionsFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "DELETE_QUESTIONS_FAILED",
		Message: "failed to delete questions",
	}

	ErrDeleteQuestionnaireFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "DELETE_QUESTIONNAIRE_FAILED",
		Message: "failed to delete questionnaire",
	}
)

// NewValidationError creates a new validation error
func NewValidationError(code, message string) *AppError {
	return &AppError{
		Type:    ErrTypeValidation,
		Code:    code,
		Message: message,
	}
}

// NewNotFoundError creates a new not found error
func NewNotFoundError(code, message string) *AppError {
	return &AppError{
		Type:    ErrTypeNotFound,
		Code:    code,
		Message: message,
	}
}

// NewInternalError creates a new internal error
func NewInternalError(code, message string, cause error) *AppError {
	return &AppError{
		Type:    ErrTypeInternal,
		Code:    code,
		Message: message,
		Cause:   cause,
	}
}

// NewDatabaseError creates a new database error
func NewDatabaseError(code, message string, cause error) *AppError {
	return &AppError{
		Type:    ErrTypeDatabase,
		Code:    code,
		Message: message,
		Cause:   cause,
	}
}
