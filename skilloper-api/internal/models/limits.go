package models

const (
	MinOptionsLimit   = 2
	MaxOptionsLimit   = 8
	DefaultMaxOptions = 4

	MaxQuestionsPerQuiz = 500

	MaxTitleLength       = 255
	MaxDescriptionLength = 1000

	MaxAlternativeQuestions = 10
	MaxExtraOptions         = 20

	StaleAttemptHours = 24

	ScorePercentage = 100

	MaxImportFileSize  = 10 * 1024 * 1024
	MaxRequestBodySize = 1 * 1024 * 1024
)

const (
	FormatJSON = "json"
)
