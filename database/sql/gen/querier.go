// Code generated by sqlc. DO NOT EDIT.
// versions:
//   sqlc v1.26.0

package gen

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

type Querier interface {
	ContributeToGoal(ctx context.Context, userID string, goalID string, amount float32, description string, accountNumber string) error
	CreateAccount(ctx context.Context, userID string, accountName string, initialBalance float32) error
	CreateBeneficiary(ctx context.Context, userID string, name string, accountNumber string, description string) error
	CreateCategory(ctx context.Context, name string, description string, userID string) error
	CreateGoal(ctx context.Context, userID string, name string, targetAmount float32, description string) error
	CreatePassword(ctx context.Context, userID string, password string) error
	CreateUser(ctx context.Context, email string, authID string, phoneNumber string, password string, name string, avatarUrl string) (*Userpayload, error)
	DeleteAccount(ctx context.Context, accountNumber string, userID string) error
	DeleteBeneficiary(ctx context.Context, beneficiaryID string, userID string) error
	DeleteCategory(ctx context.Context, categoryID string, userID string) error
	DeleteGoal(ctx context.Context, goalID string, userID string) error
	DeleteTransaction(ctx context.Context, transactionID string, userID string) error
	Deposit(ctx context.Context, userID string, accountNumber string, categoryID string, amount float32, description string) error
	GetAccountTransactions(ctx context.Context, userID string, accountNumber string, startDate pgtype.Timestamp, endDate pgtype.Timestamp, pageNumber int32, pageSize int32) ([]*Transactionpayload, error)
	GetAccounts(ctx context.Context, userID string) ([]*Accountpayload, error)
	GetBeneficiaries(ctx context.Context, userID string, pageNumber int32, pageSize int32) ([]*Beneficiarypayload, error)
	GetBeneficiary(ctx context.Context, beneficiaryID string, userID string) (*Beneficiarypayload, error)
	GetCategoriesForUser(ctx context.Context, userID string) ([]*Categorypayload, error)
	GetCategoryTransactions(ctx context.Context, userID string, categoryID string, startDate pgtype.Timestamp, endDate pgtype.Timestamp, pageNumber int32, pageSize int32) ([]*Transactionpayload, error)
	GetGoalTransactions(ctx context.Context, userID string, goalID string, startDate pgtype.Timestamp, endDate pgtype.Timestamp, pageNumber int32, pageSize int32) ([]*Transactionpayload, error)
	GetTransactionById(ctx context.Context, transactionID string, userID string) (*Transactionpayload, error)
	GetTransactionsByType(ctx context.Context, userID string, transactionType string, startDate pgtype.Timestamp, endDate pgtype.Timestamp, pageNumber int32, pageSize int32) ([]*Transactionpayload, error)
	GetUserByEmail(ctx context.Context, email string) (*Userpayload, error)
	GetUserByID(ctx context.Context, userID string) (*Userpayload, error)
	GetUserStats(ctx context.Context, email string) (*Userstats, error)
	GetUserTransactions(ctx context.Context, userID string, startDate pgtype.Timestamp, endDate pgtype.Timestamp, pageNumber int32, pageSize int32) ([]*Transactionpayload, error)
	GetUsers(ctx context.Context) ([]*Userpayload, error)
	ListUserGoals(ctx context.Context, userID string, pageNumber int32, pageSize int32) ([]*Goalpayload, error)
	LoginUser(ctx context.Context, authID string, email string, name string, phoneNumber string, avatarUrl string) (*Userpayload, error)
	LoginWithPassword(ctx context.Context, userID string, password string) (*Userpayload, error)
	RevokePassword(ctx context.Context, userID string) error
	Transfer(ctx context.Context, userID string, fromAccountNumber string, toAccountNumber string, amount float32, description string) error
	UpdateAccount(ctx context.Context, accountNumber string, userID string, accountName string) error
	UpdateBeneficiary(ctx context.Context, beneficiaryID string, userID string, name string, accountNumber string, description string) error
	UpdateCategory(ctx context.Context, categoryID string, name string, description string) error
	UpdateGoal(ctx context.Context, goalID string, userID string, name string, targetAmount float32, description string) error
	UpdateTransaction(ctx context.Context, transactionID string, userID string, accountNumber string, categoryID string, transactionType string, amount float32, description string) error
	UpdateUser(ctx context.Context, userID string, name string, phoneNumber string, avatarUrl string) (*Userpayload, error)
	Withdraw(ctx context.Context, userID string, accountNumber string, categoryID string, amount float32, description string) error
}

var _ Querier = (*Queries)(nil)
