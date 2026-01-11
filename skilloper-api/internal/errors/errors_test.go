package errors

import (
	"errors"
	"fmt"
	"testing"
)

func TestAppError_Error(t *testing.T) {
	tests := []struct {
		name    string
		err     *AppError
		wantMsg string
	}{
		{
			name: "without cause",
			err: &AppError{
				Type:    ErrTypeValidation,
				Code:    "TEST_ERROR",
				Message: "test message",
			},
			wantMsg: "TEST_ERROR: test message",
		},
		{
			name: "with cause",
			err: &AppError{
				Type:    ErrTypeInternal,
				Code:    "TEST_ERROR",
				Message: "test message",
				Cause:   fmt.Errorf("underlying error"),
			},
			wantMsg: "TEST_ERROR: test message (caused by: underlying error)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.err.Error(); got != tt.wantMsg {
				t.Errorf("Error() = %q, want %q", got, tt.wantMsg)
			}
		})
	}
}

func TestAppError_Unwrap(t *testing.T) {
	cause := fmt.Errorf("root cause")
	err := &AppError{
		Type:    ErrTypeDatabase,
		Code:    "DB_ERROR",
		Message: "database failed",
		Cause:   cause,
	}

	if got := err.Unwrap(); got != cause {
		t.Errorf("Unwrap() = %v, want %v", got, cause)
	}

	// Test nil cause
	errNoCause := &AppError{
		Type:    ErrTypeValidation,
		Code:    "TEST",
		Message: "test",
	}
	if got := errNoCause.Unwrap(); got != nil {
		t.Errorf("Unwrap() = %v, want nil", got)
	}
}

func TestAppError_Is(t *testing.T) {
	tests := []struct {
		name   string
		err    *AppError
		target error
		want   bool
	}{
		{
			name: "same code matches",
			err: &AppError{
				Code: "QUIZ_NOT_FOUND",
			},
			target: ErrQuizNotFound,
			want:   true,
		},
		{
			name: "different code does not match",
			err: &AppError{
				Code: "QUIZ_NOT_FOUND",
			},
			target: ErrAttemptNotFound,
			want:   false,
		},
		{
			name: "non-AppError target does not match",
			err: &AppError{
				Code: "TEST",
			},
			target: fmt.Errorf("not an AppError"),
			want:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.err.Is(tt.target); got != tt.want {
				t.Errorf("Is() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestAppError_ErrorsIs(t *testing.T) {
	// Test that errors.Is works correctly with wrapped AppErrors
	cause := ErrQuizNotFound
	wrapped := &AppError{
		Type:    ErrTypeDatabase,
		Code:    "WRAPPED",
		Message: "wrapper",
		Cause:   cause,
	}

	// errors.Is should find the wrapped error
	if !errors.Is(wrapped, cause) {
		t.Error("errors.Is should find wrapped ErrQuizNotFound")
	}
}

func TestAppError_ErrorsUnwrap(t *testing.T) {
	// Test that errors.Unwrap works correctly
	cause := fmt.Errorf("original error")
	appErr := &AppError{
		Type:    ErrTypeInternal,
		Code:    "TEST",
		Message: "test",
		Cause:   cause,
	}

	if errors.Unwrap(appErr) != cause {
		t.Error("errors.Unwrap should return the cause")
	}
}

func TestNewValidationError(t *testing.T) {
	err := NewValidationError("CUSTOM_CODE", "custom message")

	if err.Type != ErrTypeValidation {
		t.Errorf("Type = %v, want %v", err.Type, ErrTypeValidation)
	}
	if err.Code != "CUSTOM_CODE" {
		t.Errorf("Code = %q, want %q", err.Code, "CUSTOM_CODE")
	}
	if err.Message != "custom message" {
		t.Errorf("Message = %q, want %q", err.Message, "custom message")
	}
	if err.Cause != nil {
		t.Errorf("Cause = %v, want nil", err.Cause)
	}
}

func TestNewNotFoundError(t *testing.T) {
	err := NewNotFoundError("RESOURCE_NOT_FOUND", "resource not found")

	if err.Type != ErrTypeNotFound {
		t.Errorf("Type = %v, want %v", err.Type, ErrTypeNotFound)
	}
	if err.Code != "RESOURCE_NOT_FOUND" {
		t.Errorf("Code = %q, want %q", err.Code, "RESOURCE_NOT_FOUND")
	}
}

func TestNewInternalError(t *testing.T) {
	cause := fmt.Errorf("underlying failure")
	err := NewInternalError("INTERNAL_FAIL", "something broke", cause)

	if err.Type != ErrTypeInternal {
		t.Errorf("Type = %v, want %v", err.Type, ErrTypeInternal)
	}
	if err.Cause != cause {
		t.Errorf("Cause = %v, want %v", err.Cause, cause)
	}
}

func TestNewDatabaseError(t *testing.T) {
	cause := fmt.Errorf("db connection failed")
	err := NewDatabaseError("DB_CONN_FAILED", "database error", cause)

	if err.Type != ErrTypeDatabase {
		t.Errorf("Type = %v, want %v", err.Type, ErrTypeDatabase)
	}
	if err.Cause != cause {
		t.Errorf("Cause = %v, want %v", err.Cause, cause)
	}
}

func TestPredefinedErrors(t *testing.T) {
	// Verify some predefined errors have correct types
	tests := []struct {
		name    string
		err     *AppError
		wantTyp ErrorType
	}{
		{"ErrQuizNotFound", ErrQuizNotFound, ErrTypeNotFound},
		{"ErrNotQuizOwner", ErrNotQuizOwner, ErrTypeAuthorization},
		{"ErrQuizTitleRequired", ErrQuizTitleRequired, ErrTypeValidation},
		{"ErrFetchQuizzesFailed", ErrFetchQuizzesFailed, ErrTypeDatabase},
		{"ErrInvalidCredentials", ErrInvalidCredentials, ErrTypeAuthentication},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.err.Type != tt.wantTyp {
				t.Errorf("%s.Type = %v, want %v", tt.name, tt.err.Type, tt.wantTyp)
			}
		})
	}
}
