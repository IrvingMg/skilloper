package services

import (
	"bytes"
	"encoding/csv"
	"fmt"
	"io"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

// sanitizeCSVValue removes potential CSV formula injection prefixes
func sanitizeCSVValue(s string) string {
	s = strings.TrimSpace(s)
	if len(s) == 0 {
		return s
	}
	// Prefix dangerous characters with quote to prevent formula execution in Excel/Sheets
	switch s[0] {
	case '=', '+', '-', '@', '\t', '\r':
		return "'" + s
	}
	return s
}

// CSVParserAdapter implements QuizParser for CSV format
type CSVParserAdapter struct {
	parser *CSVParser
}

// NewCSVParserAdapter creates a new CSV parser adapter
func NewCSVParserAdapter() *CSVParserAdapter {
	return &CSVParserAdapter{
		parser: NewCSVParser(),
	}
}

// FormatName returns the format name
func (a *CSVParserAdapter) FormatName() string {
	return "csv"
}

// CanParse checks if data is in CSV format (by file extension)
func (a *CSVParserAdapter) CanParse(_ []byte, filename string) bool {
	ext := strings.ToLower(filepath.Ext(filename))
	return ext == ".csv"
}

// Parse converts CSV to internal format
func (a *CSVParserAdapter) Parse(data []byte, metadata ParserMetadata) (*models.CreateQuizRequest, error) {
	csvMeta := CSVMetadata{
		Title:       metadata.Title,
		Description: metadata.Description,
		Type:        metadata.Type,
		MaxOptions:  metadata.MaxOptions,
	}

	// If no title provided, use filename without extension
	if csvMeta.Title == "" && metadata.Filename != "" {
		ext := filepath.Ext(metadata.Filename)
		title := strings.TrimSuffix(metadata.Filename, ext)
		// Enforce title length limit for filename-derived titles
		if len(title) > models.MaxTitleLength {
			title = title[:models.MaxTitleLength]
		}
		csvMeta.Title = title
	}

	return a.parser.ParseCSV(bytes.NewReader(data), csvMeta)
}

// CSVParser handles parsing CSV files into quiz format
type CSVParser struct{}

// NewCSVParser creates a new CSV parser
func NewCSVParser() *CSVParser {
	return &CSVParser{}
}

// CSVMetadata holds quiz metadata passed via query params for CSV imports
type CSVMetadata struct {
	Title       string
	Description string
	Type        string // "practice" or "exam"
	MaxOptions  int
}

// ParseCSV converts CSV data to CreateQuizRequest
// Expected CSV format:
// question,option1,option2,option3,option4,answer,explanation,code,language,alt_question1,alt_option1
// "What is 2+2?","1","2","3","4",4,"Basic math","","","",""
// "Select primes","2","3","4","5","1,2,4","Multiple correct","","","",""
//
// Required columns:
// - question: The question text
// - option1, option2, ... option8: Answer options (at least 2 required)
// - answer: single number or comma-separated for multiple choice (1-based)
//
// Optional columns:
// - explanation: Why the answer is correct
// - code: Code snippet to display with the question
// - language: Programming language for syntax highlighting
// - alt_question1, alt_question2, ...: Alternative question phrasings
// - alt_option1, alt_option2, ...: Additional distractor options
func (p *CSVParser) ParseCSV(reader io.Reader, metadata CSVMetadata) (*models.CreateQuizRequest, error) {
	if metadata.Title == "" {
		return nil, fmt.Errorf("title is required for CSV import")
	}

	csvReader := csv.NewReader(reader)
	csvReader.FieldsPerRecord = -1
	csvReader.TrimLeadingSpace = true

	header, err := csvReader.Read()
	if err != nil {
		return nil, fmt.Errorf("failed to read CSV header - ensure file is valid CSV format")
	}

	cols, err := p.parseHeader(header)
	if err != nil {
		return nil, err
	}

	questions := []models.QuestionRequest{}
	rowNum := 1 // Start at 1 (after header)

	for {
		rowNum++
		record, err := csvReader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("row %d: failed to read - check for unquoted commas or special characters", rowNum)
		}

		if p.isEmptyRow(record) {
			continue
		}

		// Enforce row limit to prevent DoS
		if len(questions) >= models.MaxQuestionsPerQuiz {
			return nil, fmt.Errorf("CSV exceeds maximum of %d questions", models.MaxQuestionsPerQuiz)
		}

		question, err := p.parseRow(record, cols, rowNum)
		if err != nil {
			return nil, fmt.Errorf("row %d: %w", rowNum, err)
		}
		questions = append(questions, *question)
	}

	if len(questions) == 0 {
		return nil, fmt.Errorf("CSV contains no valid questions")
	}

	quizType := metadata.Type
	if quizType == "" {
		quizType = "practice"
	}
	if quizType != "practice" && quizType != "exam" {
		return nil, fmt.Errorf("type must be 'practice' or 'exam', got '%s'", quizType)
	}

	return &models.CreateQuizRequest{
		Title:       metadata.Title,
		Description: metadata.Description,
		Type:        quizType,
		MaxOptions:  metadata.MaxOptions,
		Questions:   questions,
	}, nil
}

// columnIndices holds parsed CSV header column positions
type columnIndices struct {
	question             int
	options              []int // indices of option1, option2, etc.
	answer               int
	explanation          int
	code                 int
	language             int
	alternativeQuestions []int // indices of alt_question1, alt_question2, etc.
	alternativeOptions   []int // indices of alt_option1, alt_option2, etc.
}

// parseHeader extracts column indices from CSV header
func (p *CSVParser) parseHeader(header []string) (*columnIndices, error) {
	cols := &columnIndices{
		question:             -1,
		answer:               -1,
		explanation:          -1,
		code:                 -1,
		language:             -1,
		options:              []int{},
		alternativeQuestions: []int{},
		alternativeOptions:   []int{},
	}

	for i, col := range header {
		col = strings.ToLower(strings.TrimSpace(col))
		switch {
		case col == "question":
			cols.question = i
		case strings.HasPrefix(col, "alt_question") || strings.HasPrefix(col, "alternative_question"):
			cols.alternativeQuestions = append(cols.alternativeQuestions, i)
		case strings.HasPrefix(col, "alt_option") || strings.HasPrefix(col, "alternative_option"):
			cols.alternativeOptions = append(cols.alternativeOptions, i)
		case strings.HasPrefix(col, "option"):
			cols.options = append(cols.options, i)
		case col == "answer":
			cols.answer = i
		case col == "explanation":
			cols.explanation = i
		case col == "code":
			cols.code = i
		case col == "language":
			cols.language = i
		}
	}

	if cols.question == -1 {
		return nil, fmt.Errorf("CSV header must include 'question' column")
	}
	if len(cols.options) < 2 {
		return nil, fmt.Errorf("CSV header must include at least 2 option columns (option1, option2, ...)")
	}
	if cols.answer == -1 {
		return nil, fmt.Errorf("CSV header must include 'answer' column")
	}

	return cols, nil
}

func (p *CSVParser) parseRow(record []string, cols *columnIndices, _ int) (*models.QuestionRequest, error) {
	if cols.question >= len(record) {
		return nil, fmt.Errorf("missing question column")
	}
	questionText := sanitizeCSVValue(record[cols.question])
	if questionText == "" {
		return nil, fmt.Errorf("question text is empty")
	}

	// Options must be contiguous (no gaps) to prevent index confusion
	options := []string{}
	firstEmptyIdx := -1 // Track which option column was first empty (1-based for user display)
	for i, optIdx := range cols.options {
		if optIdx < len(record) {
			opt := sanitizeCSVValue(record[optIdx])
			if opt != "" {
				if firstEmptyIdx >= 0 {
					// Found non-empty after empty - report 1-based option numbers
					return nil, fmt.Errorf("option%d is empty but option%d has a value - options must be contiguous with no gaps", firstEmptyIdx, i+1)
				}
				options = append(options, opt)
			} else if firstEmptyIdx < 0 {
				firstEmptyIdx = i + 1 // Store 1-based index
			}
		} else if firstEmptyIdx < 0 {
			firstEmptyIdx = i + 1 // Store 1-based index
		}
	}
	if len(options) < 2 {
		return nil, fmt.Errorf("at least 2 options required, got %d", len(options))
	}

	if cols.answer >= len(record) {
		return nil, fmt.Errorf("missing answer column")
	}
	answerStr := strings.TrimSpace(record[cols.answer])
	if answerStr == "" {
		return nil, fmt.Errorf("answer is empty")
	}

	question := &models.QuestionRequest{
		Question: questionText,
		Options:  options,
	}

	if strings.Contains(answerStr, ",") {
		answers, err := p.parseMultipleAnswers(answerStr, len(options))
		if err != nil {
			return nil, fmt.Errorf("invalid answer: %w", err)
		}
		question.QuestionType = models.QuestionTypeMultipleChoice
		question.CorrectAnswers = answers
	} else {
		answer, err := p.parseSingleAnswer(answerStr, len(options))
		if err != nil {
			return nil, fmt.Errorf("invalid answer: %w", err)
		}
		question.QuestionType = models.QuestionTypeSingleChoice
		question.CorrectAnswer = answer
	}

	if cols.explanation >= 0 && cols.explanation < len(record) {
		question.Explanation = sanitizeCSVValue(record[cols.explanation])
	}
	if cols.code >= 0 && cols.code < len(record) {
		question.Code = strings.TrimSpace(record[cols.code]) // Don't sanitize - may start with special chars
	}
	if cols.language >= 0 && cols.language < len(record) {
		question.Language = strings.TrimSpace(record[cols.language])
	}

	for i, idx := range cols.alternativeQuestions {
		if i >= models.MaxAlternativeQuestions {
			break
		}
		if idx < len(record) {
			altQ := sanitizeCSVValue(record[idx])
			if altQ != "" {
				question.AlternativeQuestions = append(question.AlternativeQuestions, altQ)
			}
		}
	}

	for i, idx := range cols.alternativeOptions {
		if i >= models.MaxAlternativeOptions {
			break
		}
		if idx < len(record) {
			altOpt := sanitizeCSVValue(record[idx])
			if altOpt != "" {
				question.AlternativeOptions = append(question.AlternativeOptions, altOpt)
			}
		}
	}

	return question, nil
}

// parseSingleAnswer parses a single answer value (1-based input, 0-based output)
func (p *CSVParser) parseSingleAnswer(s string, numOptions int) (int, error) {
	answer, err := strconv.Atoi(s)
	if err != nil {
		return 0, fmt.Errorf("must be a number, got '%s'", s)
	}
	if answer < 1 || answer > numOptions {
		return 0, fmt.Errorf("must be between 1 and %d, got %d", numOptions, answer)
	}
	return answer - 1, nil // Convert to 0-based for internal API
}

// parseMultipleAnswers parses comma-separated answers (1-based input, 0-based output)
func (p *CSVParser) parseMultipleAnswers(s string, numOptions int) ([]int, error) {
	parts := strings.Split(s, ",")
	answers := []int{}
	seen := make(map[int]bool)

	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		answer, err := strconv.Atoi(part)
		if err != nil {
			return nil, fmt.Errorf("'%s' is not a valid number", part)
		}
		if answer < 1 || answer > numOptions {
			return nil, fmt.Errorf("%d must be between 1 and %d", answer, numOptions)
		}
		if seen[answer] {
			return nil, fmt.Errorf("duplicate answer value: %d", answer)
		}
		seen[answer] = true
		answers = append(answers, answer-1) // Convert to 0-based for internal API
	}

	if len(answers) == 0 {
		return nil, fmt.Errorf("no valid answers found")
	}

	return answers, nil
}

// isEmptyRow checks if all cells in a row are empty
func (p *CSVParser) isEmptyRow(record []string) bool {
	for _, cell := range record {
		if strings.TrimSpace(cell) != "" {
			return false
		}
	}
	return true
}
