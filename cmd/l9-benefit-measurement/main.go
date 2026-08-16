// Command l9-benefit-measurement is the L9 benefit-measurement Phase 0 stub.
//
// It replaces the design-doc's claimed l9_benefit_measurement.py, which was
// never created (L9 audit finding, 2026-08-08). Written in Go per operator
// convention.
//
// Behaviour: queries the live Langfuse observations API; when zero agent
// traces are available (the current state) it writes verdict "no_data" to
// data/benefit/<proposal-id>.json (default daily.json). The verdict file
// shape is forward-compatible with M1-M10 metric computation once traces
// flow (L9 Phase 1), so this stub makes the pipeline ready for them.
//
// Usage:
//
//	langfuse L9_BENEFIT_MEASUREMENT  (see env vars below)
//	l9-benefit-measurement [--proposal <id>] [--langfuse-url <url>]
//
// Env:
//
//	LANGFUSE_INIT_PROJECT_PUBLIC_KEY   (pk-lf-...)
//	LANGFUSE_INIT_PROJECT_SECRET_KEY   (sk-lf-...)
//	LANGFUSE_INIT_PROJECT_ID
//	NIGHTFORGE_ROOT                    (override verdict output root)
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/ForeverLX/nightforge/internal/l9benefit"
)

func main() {
	var (
		proposal   = flag.String("proposal", "", "proposal id for the verdict filename (empty => daily.json)")
		langfuseURL = flag.String("langfuse-url", "", "Langfuse base URL (default http://127.0.0.1:31747)")
	)
	flag.Parse()

	client := &l9benefit.LangfuseClient{
		BaseURL:   *langfuseURL,
		PublicKey: envFirst("LANGFUSE_INIT_PROJECT_PUBLIC_KEY"),
		SecretKey: envFirst("LANGFUSE_INIT_PROJECT_SECRET_KEY"),
	}

	from := time.Now().UTC().AddDate(0, 0, -7)
	to := time.Now().UTC()

	obs, fetchErr := client.FetchObservations()
	client.Now = to // keep a stable window reference for the verdict
	v := l9benefit.NoDataVerdict(*proposal, from, to, obs, fetchErr)

	path, err := l9benefit.WriteVerdict(v)
	if err != nil {
		log.Fatalf("[l9-benefit-measurement] %v", err)
	}
	fmt.Printf("L9 benefit measurement: verdict=%s observations=%d agent_traces=%d\n",
		v.Verdict, v.Window.Observations, v.Window.AgentTraces)
	fmt.Printf("  verdict file: %s\n", path)
	if fetchErr != nil {
		fmt.Printf("  langfuse fetch error (treated as no data): %v\n", fetchErr)
	}
}

// envFirst returns the first non-empty env var among the given names.
func envFirst(names ...string) string {
	for _, n := range names {
		if v := os.Getenv(n); v != "" {
			return v
		}
	}
	return ""
}
