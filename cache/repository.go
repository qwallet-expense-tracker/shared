package cache

import (
	"context"
	"time"
)

type cache struct {
	ICache
}

// New returns a new cache instance
func New() ICache {
	return &cache{}
}

// Get returns the value of the key
func (c *cache) Get(ctx context.Context, key string) (string, error) {
	return GetCacheClient().Get(ctx, key).Result()
}

// Set sets the value of the key
func (c *cache) Set(ctx context.Context, key, value string, expiration time.Duration) error {
	return GetCacheClient().Set(ctx, key, value, expiration).Err()
}

// Delete deletes the key
func (c *cache) Delete(ctx context.Context, key string) error {
	return GetCacheClient().Del(ctx, key).Err()
}
