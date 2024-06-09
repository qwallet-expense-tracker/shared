-- name: CreateCategory :exec
select create_category(
               @name::varchar,
               @description::varchar,
               @user_id::varchar
       );

-- name: UpdateCategory :exec
select update_category(
               @category_id::varchar,
               @name::varchar,
               @description::varchar
       );

-- name: DeleteCategory :exec
select delete_category(
               @category_id::varchar,
               @user_id::varchar
       );

-- name: GetCategoriesForUser :many
select *
from list_categories_for_user(@user_id::varchar);
