package services

import (
	"bytes"
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

func sanitizeCSVValue(s string) string {
	s = strings.TrimSpace(s)
	if len(s) == 0 {
		return s
	}
	switch s[0] {
	case '=', '+', '-', '@', '\t', '\r':
		return "'" + s
	}
	return s
}

type CSVParserAdapter struct {
	parser *CSVParser
}

func NewCSVParserAdapter() *CSVParserAdapter {
	return &CSVParserAdapter{
		parser: NewCSVParser(),
	}
}

func (a *CSVParserAdapter) FormatName() string {
	return models.FormatCSV
}

func (a *CSVParserAdapter) CanParse(_ []byte, filename string) bool {
	ext := strings.ToLower(filepath.Ext(filename))
	return ext == ".csv"
}

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

type CSVParser struct{}

func NewCSVParser() *CSVParser {
	return &CSVParser{}
}

type CSVMetadata struct {
	Title       string
	Description string
	Type        string
	MaxOptions  int
}

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
		if errors.Is(err, io.EOF) {
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
		quizType = models.QuizTypePractice
	}
	if quizType != models.QuizTypePractice && quizType != models.QuizTypeExam {
		return nil, fmt.Errorf("type must be '%s' or '%s', got '%s'", models.QuizTypePractice, models.QuizTypeExam, quizType)
	}

	return &models.CreateQuizRequest{
		Title:       metadata.Title,
		Description: metadata.Description,
		Type:        quizType,
		MaxOptions:  metadata.MaxOptions,
		Questions:   questions,
	}, nil
}

type columnIndices struct {
	question             int
	options              []int
	answer               int
	explanation          int
	code                 int
	language             int
	alternativeQuestions []int
	alternativeOptions   []int
}

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

	options := []string{}
	firstEmptyIdx := -1
	for i, optIdx := range cols.options {
		if optIdx < len(record) {
			opt := sanitizeCSVValue(record[optIdx])
			if opt != "" {
				if firstEmptyIdx >= 0 {
					return nil, fmt.Errorf("option%d is empty but option%d has a value - options must be contiguous with no gaps", firstEmptyIdx, i+1)
				}
				options = append(options, opt)
			} else if firstEmptyIdx < 0 {
				firstEmptyIdx = i + 1
			}
		} else if firstEmptyIdx < 0 {
			firstEmptyIdx = i + 1
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
		question.Code = strings.TrimSpace(record[cols.code])
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

func (p *CSVParser) parseSingleAnswer(s string, numOptions int) (int, error) {
	answer, err := strconv.Atoi(s)
	if err != nil {
		return 0, fmt.Errorf("must be a number, got '%s'", s)
	}
	if answer < 1 || answer > numOptions {
		return 0, fmt.Errorf("must be between 1 and %d, got %d", numOptions, answer)
	}
	return answer - 1, nil
}

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
		answers = append(answers, answer-1)
	}

	if len(answers) == 0 {
		return nil, fmt.Errorf("no valid answers found")
	}

	return answers, nil
}

func (p *CSVParser) isEmptyRow(record []string) bool {
	for _, cell := range record {
		if strings.TrimSpace(cell) != "" {
			return false
		}
	}
	return true
}
