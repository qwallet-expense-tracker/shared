package interfaces

import (
	"context"
	"github.com/qwallet-expense-tracker/shared/database/sql/gen"
)

type IAccountRepository interface {
	CreateAccount(context.Context, string, string, float32) error
	UpdateAccount(context.Context, string, string, string) error
	GetUserAccounts(context.Context, string) ([]*gen.Accountpayload, error)
	DeleteAccount(context.Context, string, string) error
}
