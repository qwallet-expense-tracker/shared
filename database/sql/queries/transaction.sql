-- name: GetCategoryTransactions :many
select *
from list_transactions_for_user_by_category(
        @user_id,
        @category_id,
        @start_date,
        @end_date,
        @page_number,
        @page_size
     );

-- name: GetAccountTransactions :many
select *
from list_transactions_for_user_by_account(
        @user_id,
        @account_number,
        @start_date,
        @end_date,
        @page_number,
        @page_size
     );

-- name: GetTransactionsByType :many
select *
from list_transactions_for_user_by_type(
        @user_id,
        @transaction_type,
        @start_date,
        @end_date,
        @page_number,
        @page_size
     );

-- name: GetUserTransactions :many
select *
from list_transactions_for_user(
        @user_id,
        @start_date,
        @end_date,
        @page_number,
        @page_size
     );

-- name: GetGoalTransactions :many
select *
from list_transactions_for_user_by_goal(
        @user_id,
        @goal_id,
        @start_date,
        @end_date,
        @page_number,
        @page_size
     );

-- name: Deposit :exec
select create_transaction(
               @user_id,
               @account_number,
               @category_id,
               'CREDIT',
               @amount::decimal,
               @description
       );

-- name: Withdraw :exec
select create_transaction(
               @user_id,
               @account_number,
               @category_id,
               'DEBIT',
               @amount::decimal,
               @description
       );

-- name: UpdateTransaction :exec
select update_transaction(
               @transaction_id,
               @user_id,
               @account_number,
               @category_id,
               @transaction_type,
               @amount::decimal,
               @description
       );

-- name: DeleteTransaction :exec
select delete_transaction(
               @transaction_id,
               @user_id
       );

-- name: GetTransactionById :one
select *
from get_transaction_by_id(
        @transaction_id,
        @user_id
     );

-- name: Transfer :exec
select account_to_account_transfer(
               @user_id,
               @from_account_number,
               @to_account_number,
               @amount,
               @description
       );

-- name: ContributeToGoal :exec
select contribute_to_goal(
               @user_id,
               @goal_id,
               @amount,
               @description,
               @account_number
       );
