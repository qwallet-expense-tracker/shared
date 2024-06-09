package cache

import (
	"context"
	"github.com/redis/go-redis/v9"
	"log"
)

// client is the cache client
var client *redis.Client

// Connect initializes the cache client
func Connect(address, password string, db int) error {
	log.Println("❄️connecting to cache...")
	client = redis.NewClient(&redis.Options{
		Addr:     address,
		Password: password,
		DB:       db,
	})

	// check if the connection is successful
	if _, err := client.Ping(context.Background()).Result(); err != nil {
		return err
	}
	log.Println("🚀️connected to cache")
	return nil
}

// GetCacheClient returns the cache client
func GetCacheClient() *redis.Client {
	if client == nil {
		log.Fatalln("cache client is not initialized")
	}
	return client
}
