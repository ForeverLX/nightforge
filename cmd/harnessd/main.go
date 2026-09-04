package main

import (
	"log"
	"net/http"

	"github.com/CR1MS0N-Operator/nightforge/internal/api"
	"github.com/CR1MS0N-Operator/nightforge/internal/config"
)

func main() {
	cfg := config.Load()

	log.Printf("TETHER harness control plane starting on %s", cfg.ListenAddr)
	router := api.NewRouter()

	if err := http.ListenAndServe(cfg.ListenAddr, router); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
