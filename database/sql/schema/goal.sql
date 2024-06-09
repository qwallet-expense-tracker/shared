drop table if exists GoalPayload cascade;
create table if not exists GoalPayload
(
    id          varchar        not null,
    name        varchar        not null,
    target      numeric        not null,
    description text           not null,
    balance     numeric(10, 2) not null,
    user_id     varchar        not null,
    is_deleted  boolean        not null default false
);

drop function if exists create_goal cascade;
create or replace function create_goal(
    p_user_id varchar,
    p_name varchar,
    p_target numeric,
    p_description varchar
) returns varchar as
$$
declare
    exists  boolean := false;
    goal_id varchar;
begin
    if p_target <= 0 then
        raise exception 'Target amount must be greater than 0';
    end if;

    select exists(select 1 from goalmaster g where g.userid = p_user_id and g.name = p_name)
    into exists;
    if exists then
        raise exception 'Goal % already exists', p_name;
    end if;

    if p_description is null then
        p_description := 'Create a goal to save money for a specific purpose';
    end if;

    insert into goalmaster(userid, name, target, description)
    values (p_user_id, p_name, p_target, p_description)
    returning id
        into goal_id;
    return goal_id;
end;
$$ language plpgsql;

drop function if exists delete_goal cascade;
create or replace function delete_goal(
    p_goal_id varchar,
    p_user_id varchar
) returns void as
$$
declare
    goal_exists bool = false;
begin
    select exists(select 1 from goalmaster g where g.id = p_goal_id and g.userid = p_user_id) into goal_exists;
    if not goal_exists then
        raise exception 'Goal % does not exist', p_goal_id;
    end if;

    delete
    from goalmaster
    where id = p_goal_id
      and userid = p_user_id;
end;
$$ language plpgsql;

drop function if exists update_goal cascade;
create or replace function update_goal(
    p_goal_id varchar,
    p_user_id varchar,
    p_name varchar,
    p_target numeric,
    p_description varchar
) returns void as
$$
begin
    if p_target <= 0 then
        raise exception 'Target amount must be greater than 0';
    end if;

    update goalmaster
    set name        = p_name,
        target      = p_target,
        description = p_description
    where id = p_goal_id
      and userid = p_user_id;
end;
$$ language plpgsql;

drop function if exists list_goals_for_user cascade;
create or replace function list_goals_for_user(
    p_user_id varchar,
    p_page_number int,
    p_page_size int
)
    returns setof goalpayload
as
$$
declare
begin
    if p_page_number < 1 then
        raise exception 'Page number must be greater than 0';
    end if;

    if p_page_size < 1 then
        raise exception 'Page size must be greater than 0';
    end if;

    return query
        select g.id, g.name, g.target, g.description, g.balance, g.userid, false
        from goalmaster g
        where userid = p_user_id
        order by updatedat desc
        limit p_page_size offset (p_page_number - 1) * p_page_size;
end;
$$ language plpgsql;

drop function if exists update_goal_balance cascade;
create or replace function update_goal_balance()
    returns trigger as
$$
declare
    goal_data    record;
    goal_status  varchar;
    goal_balance numeric;
begin

    select g.target, coalesce(sum(t.amount), 0) as total_contributed
    into goal_data
    from goalmaster g
             left join transactionmaster t on t.referencenumber = g.id
    where g.id = new.referencenumber
    group by g.target;

    if goal_data.target is null then
        raise notice 'Goal % does not exist', new.referencenumber;
        return new;
    end if;


    if goal_data.target > 0 then
        goal_balance := goal_data.target - goal_data.total_contributed;

        if goal_balance <= 0 or goal_data.total_contributed >= goal_data.target then
            goal_status := 'COMPLETED';
        else
            goal_status := 'IN_PROGRESS';
        end if;

        update goalmaster
        set percentagecontributed = (goal_data.total_contributed / goal_data.target) * 100,
            amountcontributed     = goal_data.total_contributed,
            status                = goal_status,
            balance               = goal_balance
        where id = new.referencenumber;
    end if;

    return new;
end;
$$
    language plpgsql;

drop function if exists rollback_transactions() cascade;
create or replace function rollback_transactions()
    returns trigger as
$$
declare
    account_id         varchar;
    category_id        varchar;
    amount_contributed numeric;
    accounts_array     varchar[];
    category_array     varchar[];
    amount_array       numeric[];
begin
    if old.status = 'COMPLETED' then
        raise notice 'Goal % has already been completed', old.id;
        return old;
    end if;

    select array_agg(distinct t.accountid), array_agg(t.categoryid), array_agg(t.amount)
    into accounts_array, category_array, amount_array
    from transactionmaster t
    where t.referencenumber = old.id
      and t.userid = old.userid;

    if accounts_array is null or array_length(accounts_array, 1) = 0 then
        raise notice 'No transactions found for goal %', old.id;
        return old;
    end if;

    for i in 1..array_length(accounts_array, 1)
        loop
            account_id := accounts_array[i];
            category_id := category_array[i];
            amount_contributed := amount_array[i];

            insert into transactionmaster(userid, accountid, categoryid, amount, referencenumber, type, lasteditby, description)
            values (old.userid, account_id, category_id, amount_contributed, gen_random_transaction_ref_number(), 'CREDIT', old.userid,
                    'Rollback transaction for deleted goal');
        end loop;

    insert into goaltrashmaster(tid, id, userid, name, target, balance, status, amountcontributed, percentagecontributed, description, createdat)
    values (gen_random_shard_id(), old.id, old.userid, old.name, old.target, old.balance, 'CANCELLED', old.amountcontributed, old
        .percentagecontributed, old.description,
            old.updatedat);

    return old;
end;
$$ language plpgsql;

drop function if exists notify_goals cascade;
create or replace function notify_goals()
    returns trigger as
$$
declare
    user_id varchar;
    payload goalpayload;
begin
    if tg_op = 'DELETE' then
        select u.id
        into user_id
        from usermaster u
        where u.id = old.userid;

        if user_id is null then
            raise exception 'User % does not exist', old.userid;
        end if;

        select old.id, old.name, old.target, old.description, old.balance, old.userid, true
        into payload;
    else
        select u.id
        into user_id
        from usermaster u
        where u.id = new.userid;

        if user_id is null then
            raise exception 'User % does not exist', new.userid;
        end if;

        select new.id, new.name, new.target, new.description, new.balance, new.userid, false
        into payload;
    end if;

    perform pg_notify('goals', row_to_json(payload)::text);
    return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_update_updated_at_column on goalmaster cascade;
create or replace trigger trigger_update_updated_at_column
    before update
    on goalmaster
    for each row
execute function update_updated_at_column();

drop trigger if exists trigger_rollback_transactions on goalmaster cascade;
create or replace trigger trigger_rollback_transactions
    after delete
    on goalmaster
    for each row
execute function rollback_transactions();

drop trigger if exists trigger_notify_goals on goalmaster cascade;
create or replace trigger trigger_notify_goals
    after insert or update or delete
    on goalmaster
    for each row
execute function notify_goals();
