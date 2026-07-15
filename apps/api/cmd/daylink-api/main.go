package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/HCRXchenghong/life/apps/api/internal/config"
	"github.com/HCRXchenghong/life/apps/api/internal/database"
	"github.com/HCRXchenghong/life/apps/api/internal/httpapi"
)

func main() {
	if len(os.Args) == 2 && os.Args[1] == "healthcheck" {
		healthcheck()
		return
	}
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	cfg, err := config.Load()
	if err != nil {
		logger.Error("configuration rejected", "error", err.Error())
		os.Exit(1)
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	db, err := database.Open(ctx, cfg.MySQLDSN, cfg.AutoMigrate)
	if err != nil {
		logger.Error("database startup failed", "error", err.Error())
		os.Exit(1)
	}
	defer db.Close()

	server := &http.Server{
		Addr:              cfg.Address,
		Handler:           httpapi.New(cfg, db, logger).Handler(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      150 * time.Second,
		IdleTimeout:       90 * time.Second,
		MaxHeaderBytes:    32 << 10,
	}
	done := make(chan error, 1)
	go func() {
		logger.Info("daylink api listening", "address", cfg.Address)
		done <- server.ListenAndServe()
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
		defer cancel()
		if err := server.Shutdown(shutdownCtx); err != nil {
			logger.Error("graceful shutdown failed", "error", err.Error())
		}
	case err := <-done:
		if !errors.Is(err, http.ErrServerClosed) {
			logger.Error("http server stopped", "error", err.Error())
			os.Exit(1)
		}
	}
}

func healthcheck() {
	client := &http.Client{Timeout: 3 * time.Second}
	response, err := client.Get("http://127.0.0.1:8080/api/health")
	if err != nil || response.StatusCode != http.StatusOK {
		os.Exit(1)
	}
	_ = response.Body.Close()
}
