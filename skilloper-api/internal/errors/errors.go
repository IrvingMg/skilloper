package errors

import "fmt"

// ErrorType represents the type of error
type ErrorType string

const (
	// Validation errors
	ErrTypeValidation ErrorType = "validation"
	// Not found errors
	ErrTypeNotFound ErrorType = "not_found"
	// Authentication errors (login, token issues)
	ErrTypeAuthentication ErrorType = "authentication"
	// Authorization errors (permission denied)
	ErrTypeAuthorization ErrorType = "authorization"
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
		Message: "quiz not found",
	}

	ErrNotQuizOwner = &AppError{
		Type:    ErrTypeAuthorization,
		Code:    "NOT_QUIZ_OWNER",
		Message: "you don't have permission to modify this quiz",
	}

	ErrQuizTitleRequired = &AppError{
		Type:    ErrTypeValidation,
		Code:    "QUIZ_TITLE_REQUIRED",
		Message: "title is required",
	}

	ErrInvalidOptionsFormat = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_OPTIONS_FORMAT",
		Message: "invalid options format",
	}

	ErrInvalidQuizID = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_QUIZ_ID",
		Message: "invalid quiz ID",
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

	ErrFileTooLarge = &AppError{
		Type:    ErrTypeValidation,
		Code:    "FILE_TOO_LARGE",
		Message: "file exceeds maximum allowed size",
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
	ErrFetchQuizzesFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "FETCH_QUIZZES_FAILED",
		Message: "failed to fetch quizzes",
	}

	ErrFetchQuizFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "FETCH_QUIZ_FAILED",
		Message: "failed to fetch quiz",
	}

	ErrCreateQuizFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "CREATE_QUIZ_FAILED",
		Message: "failed to create quiz",
	}

	ErrCreateQuestionFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "CREATE_QUESTION_FAILED",
		Message: "failed to create question",
	}

	ErrUpdateQuizFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "UPDATE_QUIZ_FAILED",
		Message: "failed to update quiz",
	}

	ErrDeleteQuestionsFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "DELETE_QUESTIONS_FAILED",
		Message: "failed to delete questions",
	}

	ErrDeleteQuizFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "DELETE_QUIZ_FAILED",
		Message: "failed to delete quiz",
	}

	// Attempt errors
	ErrAttemptNotFound = &AppError{
		Type:    ErrTypeNotFound,
		Code:    "ATTEMPT_NOT_FOUND",
		Message: "attempt not found",
	}

	ErrInvalidAttemptData = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_ATTEMPT_DATA",
		Message: "invalid attempt data",
	}

	ErrInvalidAttemptID = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_ATTEMPT_ID",
		Message: "invalid attempt ID",
	}

	ErrCreateAttemptFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "CREATE_ATTEMPT_FAILED",
		Message: "failed to create attempt",
	}

	ErrFetchAttemptsFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "FETCH_ATTEMPTS_FAILED",
		Message: "failed to fetch attempts",
	}

	ErrFetchAttemptFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "FETCH_ATTEMPT_FAILED",
		Message: "failed to fetch attempt",
	}

	ErrInvalidPaginationParams = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_PAGINATION_PARAMS",
		Message: "invalid pagination parameters",
	}

	// Question errors
	ErrQuestionNotFound = &AppError{
		Type:    ErrTypeNotFound,
		Code:    "QUESTION_NOT_FOUND",
		Message: "question not found",
	}

	ErrInvalidQuestionID = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_QUESTION_ID",
		Message: "invalid question ID",
	}

	ErrFetchQuestionFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "FETCH_QUESTION_FAILED",
		Message: "failed to fetch question",
	}

	ErrInvalidAnswerData = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_ANSWER_DATA",
		Message: "invalid answer data",
	}

	ErrWrongAnswerFormat = &AppError{
		Type:    ErrTypeValidation,
		Code:    "WRONG_ANSWER_FORMAT",
		Message: "use user_answer for single choice or user_answers for multiple choice questions",
	}

	// Auth errors
	ErrInvalidCredentials = &AppError{
		Type:    ErrTypeAuthentication,
		Code:    "INVALID_CREDENTIALS",
		Message: "invalid username or password",
	}

	ErrUsernameTaken = &AppError{
		Type:    ErrTypeValidation,
		Code:    "USERNAME_TAKEN",
		Message: "username is already taken",
	}

	ErrUnauthorized = &AppError{
		Type:    ErrTypeAuthentication,
		Code:    "UNAUTHORIZED",
		Message: "unauthorized",
	}

	ErrInvalidToken = &AppError{
		Type:    ErrTypeAuthentication,
		Code:    "INVALID_TOKEN",
		Message: "invalid or expired token",
	}

	ErrInvalidUsername = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_USERNAME",
		Message: "username must be 6-30 characters, alphanumeric and underscore only",
	}

	ErrInvalidPassword = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_PASSWORD",
		Message: "password must be 8-72 characters",
	}

	ErrWeakPassword = &AppError{
		Type:    ErrTypeValidation,
		Code:    "WEAK_PASSWORD",
		Message: "password must contain at least one uppercase letter, one lowercase letter, and one digit",
	}

	ErrAccountLocked = &AppError{
		Type:    ErrTypeAuthentication,
		Code:    "ACCOUNT_LOCKED",
		Message: "account is temporarily locked due to too many failed login attempts",
	}

	ErrAdminSelfDeletion = &AppError{
		Type:    ErrTypeValidation,
		Code:    "ADMIN_SELF_DELETION",
		Message: "admin users cannot delete their own account",
	}

	ErrInvalidAdminUsername = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_ADMIN_USERNAME",
		Message: "ADMIN_USERNAME must be 6-30 chars, alphanumeric and underscore only",
	}

	ErrInvalidAdminPassword = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_ADMIN_PASSWORD",
		Message: "ADMIN_PASSWORD must be 8-72 chars with uppercase, lowercase, and digit",
	}

	ErrSamePassword = &AppError{
		Type:    ErrTypeValidation,
		Code:    "SAME_PASSWORD",
		Message: "new password must be different from current password",
	}

	// Auth middleware errors
	ErrMissingAuthHeader = &AppError{
		Type:    ErrTypeAuthentication,
		Code:    "UNAUTHORIZED",
		Message: "missing authorization header",
	}

	ErrInvalidAuthFormat = &AppError{
		Type:    ErrTypeAuthentication,
		Code:    "UNAUTHORIZED",
		Message: "invalid authorization format",
	}

	ErrMissingToken = &AppError{
		Type:    ErrTypeAuthentication,
		Code:    "UNAUTHORIZED",
		Message: "missing token",
	}

	// Collection errors
	ErrCollectionNotFound = &AppError{
		Type:    ErrTypeNotFound,
		Code:    "COLLECTION_NOT_FOUND",
		Message: "collection not found",
	}

	ErrNotCollectionOwner = &AppError{
		Type:    ErrTypeAuthorization,
		Code:    "NOT_COLLECTION_OWNER",
		Message: "you don't have permission to modify this collection",
	}

	ErrCollectionNameRequired = &AppError{
		Type:    ErrTypeValidation,
		Code:    "COLLECTION_NAME_REQUIRED",
		Message: "collection name is required",
	}

	ErrInvalidCollectionID = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_COLLECTION_ID",
		Message: "invalid collection ID",
	}

	ErrCreateCollectionFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "CREATE_COLLECTION_FAILED",
		Message: "failed to create collection",
	}

	ErrFetchCollectionsFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "FETCH_COLLECTIONS_FAILED",
		Message: "failed to fetch collections",
	}

	ErrUpdateCollectionFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "UPDATE_COLLECTION_FAILED",
		Message: "failed to update collection",
	}

	ErrDeleteCollectionFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "DELETE_COLLECTION_FAILED",
		Message: "failed to delete collection",
	}

	ErrUpdateQuizCollectionFailed = &AppError{
		Type:    ErrTypeDatabase,
		Code:    "UPDATE_QUIZ_COLLECTION_FAILED",
		Message: "failed to update quiz collection",
	}

	ErrInvalidParentCollection = &AppError{
		Type:    ErrTypeValidation,
		Code:    "INVALID_PARENT_COLLECTION",
		Message: "parent collection not found or does not belong to you",
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
