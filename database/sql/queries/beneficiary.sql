-- name: CreateBeneficiary :exec
select create_beneficiary(
               @user_id,
               @name,
               @account_number,
               @description
       );

-- name: UpdateBeneficiary :exec
select update_beneficiary(
               @beneficiary_id,
               @user_id,
               @name,
               @account_number,
               @description
       );

-- name: DeleteBeneficiary :exec
select delete_beneficiary(
               @beneficiary_id,
               @user_id
       );

-- name: GetBeneficiary :one
select *
from get_beneficiary(
        @beneficiary_id,
        @user_id
     );

-- name: GetBeneficiaries :many
select *
from list_beneficiaries_for_user(
        @user_id,
        @page_number,
        @page_size
     );
