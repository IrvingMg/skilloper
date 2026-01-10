package server

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"

	"github.com/gin-gonic/gin"
)

func TestStaticFileHandler(t *testing.T) {
	gin.SetMode(gin.TestMode)

	tmpDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(tmpDir, "index.html"), []byte("<html>index</html>"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tmpDir, "app.js"), []byte("console.log('app')"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(filepath.Join(tmpDir, "assets"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tmpDir, "assets", "style.css"), []byte("body{}"), 0644); err != nil {
		t.Fatal(err)
	}

	s := &Server{}
	handler := s.dirFileHandler(tmpDir)

	tests := []struct {
		name           string
		path           string
		expectedStatus int
		expectedCache  string
		checkBody      string
	}{
		{
			name:           "serve index.html",
			path:           "/",
			expectedStatus: http.StatusOK,
			expectedCache:  "no-cache, no-store, must-revalidate",
			checkBody:      "<html>index</html>",
		},
		{
			name:           "serve index.html explicitly",
			path:           "/index.html",
			expectedStatus: http.StatusOK,
			expectedCache:  "no-cache, no-store, must-revalidate",
		},
		{
			name:           "serve js with immutable cache",
			path:           "/app.js",
			expectedStatus: http.StatusOK,
			expectedCache:  "public, max-age=31536000, immutable",
		},
		{
			name:           "serve nested css with immutable cache",
			path:           "/assets/style.css",
			expectedStatus: http.StatusOK,
			expectedCache:  "public, max-age=31536000, immutable",
		},
		{
			name:           "SPA fallback for unknown route",
			path:           "/dashboard",
			expectedStatus: http.StatusOK,
			expectedCache:  "no-cache, no-store, must-revalidate",
			checkBody:      "<html>index</html>",
		},
		{
			name:           "SPA fallback for nested route",
			path:           "/quiz/123",
			expectedStatus: http.StatusOK,
			expectedCache:  "no-cache, no-store, must-revalidate",
		},
		{
			name:           "404 for missing file with extension",
			path:           "/missing.js",
			expectedStatus: http.StatusNotFound,
		},
		{
			name:           "404 for API routes",
			path:           "/api/v1/users",
			expectedStatus: http.StatusNotFound,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			c, _ := gin.CreateTestContext(w)
			c.Request = httptest.NewRequest("GET", tt.path, nil)

			handler(c)

			if w.Code != tt.expectedStatus {
				t.Errorf("expected status %d, got %d", tt.expectedStatus, w.Code)
			}

			if tt.expectedCache != "" {
				cache := w.Header().Get("Cache-Control")
				if cache != tt.expectedCache {
					t.Errorf("expected Cache-Control %q, got %q", tt.expectedCache, cache)
				}
			}

			if tt.checkBody != "" && w.Body.String() != tt.checkBody {
				t.Errorf("expected body %q, got %q", tt.checkBody, w.Body.String())
			}
		})
	}
}

func TestStaticFileHandler_PathTraversal(t *testing.T) {
	gin.SetMode(gin.TestMode)

	tmpDir := t.TempDir()
	staticDir := filepath.Join(tmpDir, "static")
	secretDir := filepath.Join(tmpDir, "secret")

	if err := os.Mkdir(staticDir, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(secretDir, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(staticDir, "index.html"), []byte("public"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(secretDir, "secret.txt"), []byte("secret data"), 0644); err != nil {
		t.Fatal(err)
	}

	s := &Server{}
	handler := s.dirFileHandler(staticDir)

	traversalPaths := []string{
		"/../secret/secret.txt",
		"/..%2fsecret/secret.txt",
		"/../../../etc/passwd",
		"/static/../secret/secret.txt",
		"/..",
		"/./../../secret/secret.txt",
	}

	for _, path := range traversalPaths {
		t.Run(path, func(t *testing.T) {
			w := httptest.NewRecorder()
			c, _ := gin.CreateTestContext(w)
			c.Request = httptest.NewRequest("GET", path, nil)

			handler(c)

			if w.Code != http.StatusNotFound && w.Code != http.StatusOK && w.Code != http.StatusBadRequest {
				t.Errorf("expected 400, 404, or 200 (index fallback), got %d", w.Code)
			}

			if w.Body.String() == "secret data" {
				t.Errorf("path traversal succeeded for %s - secret data exposed", path)
			}
		})
	}
}

func TestSetCacheHeaders(t *testing.T) {
	gin.SetMode(gin.TestMode)
	s := &Server{}

	tests := []struct {
		path     string
		expected string
	}{
		{"/", "no-cache, no-store, must-revalidate"},
		{"/index.html", "no-cache, no-store, must-revalidate"},
		{"/main.js", "public, max-age=31536000, immutable"},
		{"/style.css", "public, max-age=31536000, immutable"},
		{"/font.woff2", "public, max-age=31536000, immutable"},
		{"/image.png", "public, max-age=31536000, immutable"},
		{"/image.jpg", "public, max-age=31536000, immutable"},
		{"/icon.svg", "public, max-age=31536000, immutable"},
		{"/app.wasm", "public, max-age=31536000, immutable"},
		{"/data.json", "public, max-age=3600"},
		{"/manifest.webmanifest", "public, max-age=3600"},
	}

	for _, tt := range tests {
		t.Run(tt.path, func(t *testing.T) {
			w := httptest.NewRecorder()
			c, _ := gin.CreateTestContext(w)

			s.setCacheHeaders(c, tt.path)

			cache := w.Header().Get("Cache-Control")
			if cache != tt.expected {
				t.Errorf("path %s: expected %q, got %q", tt.path, tt.expected, cache)
			}
		})
	}
}

func TestEmbeddedFileHandler(t *testing.T) {
	gin.SetMode(gin.TestMode)

	mockFS := fstest.MapFS{
		"index.html":       {Data: []byte("<html>embedded</html>")},
		"app.js":           {Data: []byte("console.log('embedded')")},
		"assets/style.css": {Data: []byte("body{}")},
	}

	s := &Server{}
	handler := s.embeddedFileHandler(mockFS)

	tests := []struct {
		name           string
		path           string
		expectedStatus int
		expectedCache  string
	}{
		{
			name:           "serve index.html at root",
			path:           "/",
			expectedStatus: http.StatusOK,
			expectedCache:  "no-cache, no-store, must-revalidate",
		},
		{
			name:           "serve index.html explicitly",
			path:           "/index.html",
			expectedStatus: http.StatusOK,
			expectedCache:  "no-cache, no-store, must-revalidate",
		},
		{
			name:           "serve js with immutable cache",
			path:           "/app.js",
			expectedStatus: http.StatusOK,
			expectedCache:  "public, max-age=31536000, immutable",
		},
		{
			name:           "serve nested css",
			path:           "/assets/style.css",
			expectedStatus: http.StatusOK,
			expectedCache:  "public, max-age=31536000, immutable",
		},
		{
			name:           "SPA fallback for unknown route",
			path:           "/dashboard",
			expectedStatus: http.StatusOK,
			expectedCache:  "no-cache, no-store, must-revalidate",
		},
		{
			name:           "SPA fallback for nested route",
			path:           "/quiz/123",
			expectedStatus: http.StatusOK,
			expectedCache:  "no-cache, no-store, must-revalidate",
		},
		{
			name:           "404 for missing file with extension",
			path:           "/missing.js",
			expectedStatus: http.StatusNotFound,
		},
		{
			name:           "404 for API routes",
			path:           "/api/v1/users",
			expectedStatus: http.StatusNotFound,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			c, _ := gin.CreateTestContext(w)
			c.Request = httptest.NewRequest("GET", tt.path, nil)

			handler(c)

			if w.Code != tt.expectedStatus {
				t.Errorf("expected status %d, got %d", tt.expectedStatus, w.Code)
			}

			if tt.expectedCache != "" {
				cache := w.Header().Get("Cache-Control")
				if cache != tt.expectedCache {
					t.Errorf("expected Cache-Control %q, got %q", tt.expectedCache, cache)
				}
			}
		})
	}
}
