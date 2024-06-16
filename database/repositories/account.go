package repositories

import (
	"context"
	"github.com/qwallet-expense-tracker/shared/database"
	"github.com/qwallet-expense-tracker/shared/database/interfaces"
	"github.com/qwallet-expense-tracker/shared/database/sql/gen"
)

// AccountRepository implements the `IAccountRepository` interface
type accountRepository struct {
	interfaces.IAccountRepository
}

// NewAccountRepository creates a new instance of the `accountRepository`
func NewAccountRepository() interfaces.IAccountRepository {
	return &accountRepository{}
}

func (r *accountRepository) CreateAccount(ctx context.Context, userID string, accountName string, initialBalance float32) error {
	conn := database.GetConn()
	defer conn.Release()

	return gen.New(conn).CreateAccount(ctx, userID, accountName, initialBalance)
}

func (r *accountRepository) UpdateAccount(ctx context.Context, accountNumber, userID, accountName string) error {
	conn := database.GetConn()
	defer conn.Release()

	return gen.New(conn).UpdateAccount(ctx, accountNumber, userID, accountName)
}

func (r *accountRepository) GetUserAccounts(ctx context.Context, userID string) ([]*gen.Accountpayload, error) {
	conn := database.GetConn()
	defer conn.Release()

	return gen.New(conn).GetAccounts(ctx, userID)
}

func (r *accountRepository) DeleteAccount(ctx context.Context, accountNumber, userID string) error {
	conn := database.GetConn()
	defer conn.Release()

	return gen.New(conn).DeleteAccount(ctx, accountNumber, userID)
}
