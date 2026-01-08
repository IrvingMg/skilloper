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
	// Quiz errors
	ErrQuizNotFound = &AppError{
		Type:    ErrTypeNotFound,
		Code:    "QUIZ_NOT_FOUND",
		Message: "Quiz not found",
	}

	ErrQuizTitleRequired = &AppError{
		Type:    ErrTypeValidation,
		Code:    "QUIZ_TITLE_REQUIRED",
		Message: "Title is required",
	}

	ErrInvalidOptionsFormat = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_OPTIONS_FORMAT",
		Message: "Invalid options format",
	}

	ErrInvalidQuizID = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_QUIZ_ID",
		Message: "Invalid quiz ID",
	}

	ErrInvalidJSONFormat = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_JSON_FORMAT",
		Message: "Invalid JSON format",
	}

	ErrFileRequired = &AppError{
		Type:    ErrTypeValidation,
		Code:    "FILE_REQUIRED",
		Message: "File is required for import",
	}

	ErrFileOpenFailed = &AppError{
		Type:    ErrTypeValidation,
		Code:    "FILE_OPEN_FAILED",
		Message: "Failed to open uploaded file",
	}

	ErrFileReadFailed = &AppError{
		Type:    ErrTypeValidation,
		Code:    "FILE_READ_FAILED",
		Message: "Failed to read uploaded file",
	}

	// Question validation errors
	ErrQuestionTextRequired = &AppError{
		Type:    ErrTypeValidation,
		Code:    "QUESTION_TEXT_REQUIRED",
		Message: "Question text is required",
	}

	ErrInvalidQuestionType = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_QUESTION_TYPE",
		Message: "Invalid question type",
	}

	ErrQuestionOptionsRequired = &AppError{
		Type:    ErrTypeValidation,
		Code:    "QUESTION_OPTIONS_REQUIRED",
		Message: "Question options are required",
	}

	ErrTooManyOptions = &AppError{
		Type:    ErrTypeValidation,
		Code:    "TOO_MANY_OPTIONS",
		Message: "Too many options for question",
	}

	ErrMultipleChoiceAnswersRequired = &AppError{
		Type:    ErrTypeValidation,
		Code:    "MULTIPLE_CHOICE_ANSWERS_REQUIRED",
		Message: "Multiple choice questions require correct answers",
	}

	ErrInvalidCorrectAnswer = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_CORRECT_ANSWER",
		Message: "Invalid correct answer",
	}

	// Database operation errors
	ErrFetchQuizzesFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "FETCH_QUIZZES_FAILED",
		Message: "Failed to fetch quizzes",
	}

	ErrFetchQuizFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "FETCH_QUIZ_FAILED",
		Message: "Failed to fetch quiz",
	}

	ErrCreateQuizFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "CREATE_QUIZ_FAILED",
		Message: "Failed to create quiz",
	}

	ErrCreateQuestionFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "CREATE_QUESTION_FAILED",
		Message: "Failed to create question",
	}

	ErrUpdateQuizFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "UPDATE_QUIZ_FAILED",
		Message: "Failed to update quiz",
	}

	ErrDeleteQuestionsFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "DELETE_QUESTIONS_FAILED",
		Message: "Failed to delete questions",
	}

	ErrDeleteQuizFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "DELETE_QUIZ_FAILED",
		Message: "Failed to delete quiz",
	}

	// Attempt errors
	ErrAttemptNotFound = &AppError{
		Type:    ErrTypeNotFound,
		Code:    "ATTEMPT_NOT_FOUND",
		Message: "Attempt not found",
	}

	ErrInvalidAttemptData = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_ATTEMPT_DATA",
		Message: "Invalid attempt data",
	}

	ErrInvalidAttemptID = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_ATTEMPT_ID",
		Message: "Invalid attempt ID",
	}

	ErrCreateAttemptFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "CREATE_ATTEMPT_FAILED",
		Message: "Failed to create attempt",
	}

	ErrFetchAttemptsFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "FETCH_ATTEMPTS_FAILED",
		Message: "Failed to fetch attempts",
	}

	ErrFetchAttemptFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "FETCH_ATTEMPT_FAILED",
		Message: "Failed to fetch attempt",
	}

	ErrInvalidPaginationParams = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_PAGINATION_PARAMS",
		Message: "Invalid pagination parameters",
	}

	// Question errors
	ErrQuestionNotFound = &AppError{
		Type:    ErrTypeNotFound,
		Code:    "QUESTION_NOT_FOUND",
		Message: "Question not found",
	}

	ErrInvalidQuestionID = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_QUESTION_ID",
		Message: "Invalid question ID",
	}

	ErrFetchQuestionFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "FETCH_QUESTION_FAILED",
		Message: "Failed to fetch question",
	}

	ErrInvalidAnswerData = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_ANSWER_DATA",
		Message: "Invalid answer data",
	}

	// Auth errors
	ErrInvalidCredentials = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_CREDENTIALS",
		Message: "Invalid username or password",
	}

	ErrUsernameTaken = &AppError{
		Type:    ErrTypeValidation,
		Code:    "USERNAME_TAKEN",
		Message: "Username is already taken",
	}

	ErrUnauthorized = &AppError{
		Type:    ErrTypeValidation,
		Code:    "UNAUTHORIZED",
		Message: "Unauthorized",
	}

	ErrInvalidToken = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_TOKEN",
		Message: "Invalid or expired token",
	}

	ErrInvalidUsername = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_USERNAME",
		Message: "Username must be 6-30 characters, alphanumeric and underscore only",
	}

	ErrInvalidPassword = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_PASSWORD",
		Message: "Password must be 8-72 characters",
	}

	ErrWeakPassword = &AppError{
		Type:    ErrTypeValidation,
		Code:    "WEAK_PASSWORD",
		Message: "Password must contain at least one uppercase letter, one lowercase letter, and one digit",
	}

	ErrAccountLocked = &AppError{
		Type:    ErrTypeValidation,
		Code:    "ACCOUNT_LOCKED",
		Message: "Account is temporarily locked due to too many failed login attempts. Please try again later",
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
