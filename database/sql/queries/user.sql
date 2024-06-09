-- name: GetUsers :many
select *
from list_users();

-- name: GetUserStats :one
select *
from get_user_stats(@email::varchar);

-- name: CreateUser :one
select *
from create_user(
        @email::varchar,
        @auth_id::varchar,
        @phone_number::varchar,
        @password::varchar,
        @name::varchar,
        @avatar_url::varchar
     );

-- name: LoginUser :one
select *
from login_user(
        @auth_id::varchar,
        @email::varchar,
        @name::varchar,
        @phone_number::varchar,
        @avatar_url::varchar
     );

-- name: GetUserByID :one
select *
from get_user_by_id(@user_id::varchar);

-- name: GetUserByEmail :one
select *
from get_user_by_email(@email::varchar);

-- name: LoginWithPassword :one
select *
from login_user_with_password(
        @user_id::varchar,
        @password::varchar);


-- name: CreatePassword :exec
select create_password(
               @user_id::varchar,
               @password::varchar);

-- name: RevokePassword :exec
select revoke_password(
               @user_id::varchar);

-- name: UpdateUser :one
select *
from update_user(
        @user_id::varchar,
        @name::varchar,
        @phone_number::varchar,
        @avatar_url::varchar);