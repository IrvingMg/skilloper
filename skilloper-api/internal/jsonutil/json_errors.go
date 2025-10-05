package jsonutil

import (
	"encoding/json"
	"fmt"
	"strings"
)

// JSONErrorInfo contains detailed information about a JSON parsing error
type JSONErrorInfo struct {
	Message     string
	Line        int
	Column      int
	HasLocation bool
}

// ParseJSONError extracts detailed information from a JSON parsing error
func ParseJSONError(err error, content []byte, filename string) *JSONErrorInfo {
	errorInfo := &JSONErrorInfo{
		Message: fmt.Sprintf("JSON parsing failed in file '%s': %s", filename, err.Error()),
	}

	// Try to extract line and column information from JSON syntax errors
	if syntaxErr, ok := err.(*json.SyntaxError); ok {
		lines := strings.Split(string(content), "\n")
		lineNum := 1
		charCount := int64(0)

		for i, line := range lines {
			if charCount+int64(len(line)) >= syntaxErr.Offset {
				lineNum = i + 1
				colNum := int(syntaxErr.Offset - charCount)
				errorInfo.Line = lineNum
				errorInfo.Column = colNum
				errorInfo.HasLocation = true
				errorInfo.Message = fmt.Sprintf("JSON syntax error in file '%s' at line %d, column %d: %s", filename, lineNum, colNum, syntaxErr.Error())
				break
			}
			charCount += int64(len(line)) + 1 // +1 for newline
		}
	}

	return errorInfo
}
