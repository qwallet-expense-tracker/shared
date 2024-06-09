-- name: CreateGoal :exec
select create_goal(@user_id, @name,
                   @target_amount, @description);

-- name: UpdateGoal :exec
select update_goal(@goal_id, @user_id,
                   @name, @target_amount,
                   @description);

-- name: DeleteGoal :exec
select delete_goal(@goal_id, @user_id);

-- name: ListUserGoals :many
select *
from list_goals_for_user(@user_id, @page_number, @page_size);
