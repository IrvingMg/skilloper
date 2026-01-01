package models

// Centralized limits for questionnaire validation
// These limits are shared across all import paths (JSON, CSV, API)
// Keep in sync with Flutter app limits in lib/constants/limits.dart
const (
	// Options per question
	MinOptionsLimit   = 2 // Minimum options required per question
	MaxOptionsLimit   = 8 // Maximum options allowed per question
	DefaultMaxOptions = 4 // Default max options when not specified

	// Questions per questionnaire
	MaxQuestionsPerQuiz = 500 // Maximum questions per questionnaire

	// Field lengths
	MaxTitleLength       = 255  // Maximum title length
	MaxDescriptionLength = 1000 // Maximum description length

	// Alternative fields (for question variety)
	MaxAlternativeQuestions = 10 // Maximum alternative question phrasings
	MaxAlternativeOptions   = 20 // Maximum alternative distractor options
)
