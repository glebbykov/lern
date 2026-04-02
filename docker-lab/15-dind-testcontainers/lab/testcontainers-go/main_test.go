package main

import (
	"context"
	"database/sql"
	"testing"
	"time"

	_ "github.com/lib/pq"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"
)

func TestPostgresIntegration(t *testing.T) {
	ctx := context.Background()

	// 1. Запустить настоящий PostgreSQL в контейнере
	pgContainer, err := postgres.Run(ctx,
		"postgres:16-alpine",
		postgres.WithDatabase("testdb"),
		postgres.WithUsername("test"),
		postgres.WithPassword("test"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(30*time.Second),
		),
	)
	if err != nil {
		t.Fatalf("failed to start postgres: %v", err)
	}
	defer func() {
		if err := pgContainer.Terminate(ctx); err != nil {
			t.Logf("failed to terminate container: %v", err)
		}
	}()

	// 2. Подключиться
	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("failed to get connection string: %v", err)
	}
	t.Logf("container started: %s", connStr)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		t.Fatalf("failed to open db: %v", err)
	}
	defer db.Close()

	// 3. Создать таблицу и вставить данные
	_, err = db.Exec("CREATE TABLE notes (text TEXT)")
	if err != nil {
		t.Fatalf("failed to create table: %v", err)
	}

	_, err = db.Exec("INSERT INTO notes VALUES ($1)", "hello testcontainers")
	if err != nil {
		t.Fatalf("failed to insert: %v", err)
	}

	// 4. Прочитать и проверить
	var text string
	err = db.QueryRow("SELECT text FROM notes LIMIT 1").Scan(&text)
	if err != nil {
		t.Fatalf("failed to query: %v", err)
	}

	t.Logf("inserted and queried: %s", text)

	if text != "hello testcontainers" {
		t.Errorf("expected 'hello testcontainers', got '%s'", text)
	}
}
