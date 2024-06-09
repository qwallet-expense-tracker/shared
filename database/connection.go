package database

import (
	"context"
	"fmt"
	"github.com/jackc/pgx/v5/pgxpool"
	"log"
)

var dbPool *pgxpool.Pool

// Connect creates a new connection pool to the database
func Connect(connString string) error {
	log.Println("❄️connecting to database...")
	var err error
	dbPool, err = pgxpool.New(context.Background(), connString)
	if err != nil {
		return fmt.Errorf("Failed to create connection pool: %v\n", err)
	}
	if _, err = dbPool.Exec(context.Background(), "SELECT 1"); err != nil {
		return fmt.Errorf("Failed to ping database: %v\n", err)
	}

	log.Println("🚀connected to database")
	return nil
}

// GetConn returns the connection to the database
func GetConn() *pgxpool.Conn {
	log.Println("🚀acquiring connection to db...")
	conn, err := dbPool.Acquire(context.Background())
	if err != nil {
		log.Fatalf("Failed to acquire connection: %v\n", err)
	}
	log.Println("🚀db connection acquired")
	return conn
}
