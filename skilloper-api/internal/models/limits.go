package models

// Centralized limits for quiz validation
// These limits are shared across all import paths (JSON, CSV, API)
// Keep in sync with Flutter app limits in lib/constants/limits.dart
const (
	// Options per question
	MinOptionsLimit   = 2 // Minimum options required per question
	MaxOptionsLimit   = 8 // Maximum options allowed per question
	DefaultMaxOptions = 4 // Default max options when not specified

	// Questions per quiz
	MaxQuestionsPerQuiz = 500 // Maximum questions per quiz

	// Field lengths
	MaxTitleLength       = 255  // Maximum title length
	MaxDescriptionLength = 1000 // Maximum description length

	// Alternative fields (for question variety)
	MaxAlternativeQuestions = 10 // Maximum alternative question phrasings
	MaxAlternativeOptions   = 20 // Maximum alternative distractor options

	// Device tracking
	MaxDeviceIDLength = 128 // Maximum device ID length (UUID is 36 chars)

	// Attempt limits
	MaxConcurrentAttempts  = 2  // Maximum in-progress attempts per device per quiz
	StaleAttemptHours      = 24 // Hours after which in-progress attempts are considered stale
)
