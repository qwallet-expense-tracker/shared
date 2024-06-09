-- name: CreateAccount :exec
select
from create_new_account(
        @user_id,
        @account_name,
        @initial_balance
     );

-- name: DeleteAccount :exec
select
from delete_account_for_user(
        @account_number,
        @user_id
     );

-- name: UpdateAccount :exec
select
from update_account_for_user(
        @account_number,
        @user_id,
        @account_name
     );

-- name: GetAccounts :many
select *
from list_accounts_for_user(@user_id);
