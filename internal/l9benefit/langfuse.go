// Package l9benefit implements the L9 benefit-measurement Phase 0 stub.
//
// It is the Go replacement for the design-doc's claimed (but never created)
// l9_benefit_measurement.py. Per operator convention all new harness tooling
// is written in Go. The stub reads Langfuse trace observations from the live
// observability stack and produces a verdict file in data/benefit/.
//
// Current status (2026-08-08): Langfuse is deployed but no agent traces flow
// through it (0 real observations; only manual test payloads), so every run
// currently emits verdict "no_data". The pipeline is thereby made ready to
// produce real M1-M10 verdicts as soon as traces flow (L9 Phase 1).
package l9benefit

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// LangfuseObservationsResponse is the subset of the Langfuse v2 observations
// API response the stub needs: the list of observation spans and pagination
// metadata. Unknown fields are ignored (decoding is lenient).
type LangfuseObservationsResponse struct {
	Data       []Observation `json:"data"`
	Meta       Meta          `json:"meta"`
	NextCursor string        `json:"nextCursor"`
}

// Observation is a single Langfuse observation span.
//
// Field names follow the Langfuse v2 Observations API selective-field
// projection (https://langfuse.com/docs/api-and-data-platform/features/observations-api#key-improvements).
// The endpoint returns these fields only when the matching field group is
// requested via ?fields=; the v1 names (model, input, output, total) do not
// exist on v2 and would always decode to zero.
type Observation struct {
	ID        string  `json:"id"`
	Type      string  `json:"type"`
	Name      string  `json:"name"`
	StartTime string  `json:"startTime"`
	// providedModelName comes from the "model" field group.
	Model *string `json:"providedModelName"`
	// Usage fields (M8-M10) from the "usage" field group.
	InputTokens  int64 `json:"inputUsage"`
	OutputTokens int64 `json:"outputUsage"`
	TotalTokens  int64 `json:"totalUsage"`
	// Latency is the span duration in SECONDS from the "metrics" field group.
	Latency float64 `json:"latency"`
	Error   bool    `json:"error"`
}

// Meta carries the total observation count when the API reports it.
type Meta struct {
	TotalItems int `json:"totalItems"`
}

// LangfuseClient queries the Langfuse public observations API.
type LangfuseClient struct {
	// BaseURL is the Langfuse web root, e.g. http://127.0.0.1:31747.
	BaseURL string
	// PublicKey is the pk-lf-... project public key.
	PublicKey string
	// SecretKey is the sk-lf-... project secret key.
	SecretKey string
	// HTTP is the client used for requests; nil => http.DefaultClient.
	HTTP *http.Client
	// Now is the current time (injectable for tests); zero => time.Now.
	Now time.Time
}

func (c *LangfuseClient) resolved() {
	if c.BaseURL == "" {
		c.BaseURL = "http://127.0.0.1:31747"
	}
	if c.HTTP == nil {
		c.HTTP = http.DefaultClient
	}
	if c.Now.IsZero() {
		c.Now = time.Now()
	}
}

// FetchObservations queries the Langfuse v2 observations API for the last 7
// days and returns the spans found. An HTTP/API error is returned as a Go
// error (the caller decides whether to treat it as "no data").
func (c *LangfuseClient) FetchObservations() ([]Observation, error) {
	c.resolved()
	to := c.Now
	from := to.AddDate(0, 0, -7)
	url := fmt.Sprintf("%s/api/public/v2/observations?fromStartTime=%s&toStartTime=%s&limit=100&fields=core,basic,model,usage,metrics",
		c.BaseURL, from.Format(time.RFC3339Nano), to.Format(time.RFC3339Nano))

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	// Langfuse public API accepts HTTP Basic auth with "public:secret".
	req.SetBasicAuth(c.PublicKey, c.SecretKey)
	req.Header.Set("Accept", "application/json")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		return nil, fmt.Errorf("GET observations: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, fmt.Errorf("langfuse observations API HTTP %d: %s", resp.StatusCode, string(body))
	}

	dec := json.NewDecoder(resp.Body)
	var out LangfuseObservationsResponse
	if err := dec.Decode(&out); err != nil {
		return nil, fmt.Errorf("decode observations: %w", err)
	}
	if out.Data == nil {
		out.Data = []Observation{}
	}
	return out.Data, nil
}
