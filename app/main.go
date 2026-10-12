package main

import (
	"event-service/internal/app"
	"log"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	log.Println("Event Service starting...")

	// Load configuration
	config := app.LoadConfig()

	// Create application
	application := app.New(config)

	// Set up signal handling for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	// Start server in a goroutine
	serverErr := make(chan error, 1)
	go func() {
		serverErr <- application.Start()
	}()

	// Wait for shutdown signal or a fatal server error (e.g. port in use)
	select {
	case sig := <-sigChan:
		log.Printf("Received signal: %v", sig)
	case err := <-serverErr:
		if err != nil {
			log.Fatalf("Server error: %v", err)
		}
	}

	// Graceful shutdown
	application.Shutdown()
	log.Println("Service stopped")
}
