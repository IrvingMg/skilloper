package models

const (
	MinOptionsLimit   = 2
	MaxOptionsLimit   = 8
	DefaultMaxOptions = 4

	MaxQuestionsPerQuiz = 500

	MaxTitleLength       = 255
	MaxDescriptionLength = 1000

	MaxAlternativeQuestions = 10
	MaxAlternativeOptions   = 20

	MaxConcurrentAttempts = 2
	StaleAttemptHours     = 24

	ScorePercentage = 100

	MaxImportFileSize = 10 * 1024 * 1024
)

const (
	FormatCSV  = "csv"
	FormatJSON = "json"
)
