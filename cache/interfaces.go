package cache

import (
	"context"
	"time"
)

type ICache interface {
	Get(context.Context, string) (string, error)
	Set(context.Context, string, string, time.Duration) error

	// GetString - get a string/JSON value
	GetString(context.Context, string) (string, error)

	// GetHash - get a hash of values (e.g. a user object)
	GetHash(context.Context, string) (map[string]interface{}, error)

	// GetList - get a list of values (e.g. a list of countries etc.)
	GetList(context.Context, string) ([]any, error)

	// StoreString - store a string/JSON value
	StoreString(context.Context, string, string, time.Duration) error

	// StoreHash - store a hash of values (e.g. a user object)
	StoreHash(context.Context, string, map[string]interface{}, time.Duration) error

	// StoreList - store a list of values (e.g. a list of countries etc.)
	StoreList(context.Context, string, []any, time.Duration) error

	Delete(context.Context, string) error
}
