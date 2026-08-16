package main

import (
	"embed"
	"log"
	"net/http"
	"os"

	"github.com/ForeverLX/nightforge/internal/collector"
	"github.com/ForeverLX/nightforge/internal/server"
)

//go:embed frontend/index.html
var frontend embed.FS

func main() {
	// Start health collector
	collector.Init("data")

	// Build handler
	handler := server.New(frontend)

	addr := os.Getenv("HARNESSD_ADDRESS")
	if addr == "" {
		addr = "127.0.0.1:9191"
	}
	log.Printf("harnessd listening on %s", addr)
	if err := http.ListenAndServe(addr, handler); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
