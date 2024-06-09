// Code generated by sqlc. DO NOT EDIT.
// versions:
//   sqlc v1.26.0

package gen

import (
	"time"
)

type Accountpayload struct {
	Name          string    `json:"name"`
	Balance       float32   `json:"balance"`
	AccountNumber string    `json:"account_number"`
	UserID        string    `json:"user_id"`
	UpdatedAt     time.Time `json:"updated_at"`
	IsDeleted     bool      `json:"is_deleted"`
}

type Beneficiarypayload struct {
	ID            string    `json:"id"`
	AccountNumber string    `json:"account_number"`
	Name          string    `json:"name"`
	Description   string    `json:"description"`
	UserID        string    `json:"user_id"`
	UpdatedAt     time.Time `json:"updated_at"`
	IsDeleted     bool      `json:"is_deleted"`
}

type Categorypayload struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	UserID      string `json:"user_id"`
	IsDeleted   bool   `json:"is_deleted"`
}

type Goalpayload struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Target      float32 `json:"target"`
	Description string  `json:"description"`
	Balance     float32 `json:"balance"`
	UserID      string  `json:"user_id"`
	IsDeleted   bool    `json:"is_deleted"`
}

type Transactionpayload struct {
	ID              string    `json:"id"`
	UserID          string    `json:"user_id"`
	AccountNumber   string    `json:"account_number"`
	AccountName     string    `json:"account_name"`
	CategoryID      string    `json:"category_id"`
	Type            string    `json:"type"`
	Amount          float32   `json:"amount"`
	Description     string    `json:"description"`
	ReferenceNumber string    `json:"reference_number"`
	Status          string    `json:"status"`
	UpdatedAt       time.Time `json:"updated_at"`
	IsDeleted       bool      `json:"is_deleted"`
}

type Userpayload struct {
	ID          string `json:"id"`
	Email       string `json:"email"`
	Name        string `json:"name"`
	PhoneNumber string `json:"phone_number"`
	AvatarUrl   string `json:"avatar_url"`
	IsDeleted   bool   `json:"is_deleted"`
}

type Userstats struct {
	TotalAccounts     int64   `json:"total_accounts"`
	TotalTransactions int64   `json:"total_transactions"`
	TotalCategories   int64   `json:"total_categories"`
	TotalGoals        int64   `json:"total_goals"`
	AccountBalance    float32 `json:"account_balance"`
	AccountNumber     string  `json:"account_number"`
	TotalIncome       float32 `json:"total_income"`
	TotalExpense      float32 `json:"total_expense"`
}
type Orderable interface {
	Less(other Orderable) bool
}

func (d *Accountpayload) Less(other Orderable) bool {
	return d.UpdatedAt.Before(other.(*Accountpayload).UpdatedAt)
}

func (d *Beneficiarypayload) Less(other Orderable) bool {
	return d.UpdatedAt.Before(other.(*Beneficiarypayload).UpdatedAt)
}

func (d *Categorypayload) Less(other Orderable) bool {
	return d.ID < other.(*Categorypayload).ID
}

func (d *Goalpayload) Less(other Orderable) bool {
	return d.ID < other.(*Goalpayload).ID
}

func (d *Transactionpayload) Less(other Orderable) bool {
	return d.UpdatedAt.Before(other.(*Transactionpayload).UpdatedAt)
}

func (d *Userpayload) Less(other Orderable) bool {
	return d.ID < other.(*Userpayload).ID
}