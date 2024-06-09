drop table if exists AccountPayload cascade;
create table if not exists AccountPayload
(
    name           varchar     not null,
    balance        numeric     not null,
    account_number varchar     not null,
    user_id        varchar     not null,
    updated_at     timestamptz,
    is_deleted     boolean     not null default false
);

drop function if exists create_new_account cascade;
create or replace function create_new_account(
    p_user_id varchar,
    p_name varchar,
    p_initial_balance numeric
) returns void as
$$
declare
    user_exists            boolean = false;
    existing_account_count int     = 0;
begin
    select exists(select 1 from usermaster u where u.id = p_user_id)
    into user_exists;

    if not user_exists then
        raise exception 'User % does not exist', p_user_id;
    end if;

    select count(*)
    from accountmaster a
    where a.name = p_name
    into existing_account_count;

    if existing_account_count > 0 then
        raise exception 'An account with name % already exists', p_name;
    end if;

    insert into accountmaster(userid, balance, name, accountnumber)
    values (p_user_id, p_initial_balance, p_name, gen_random_account_number());
    raise notice 'Account created for user %', p_user_id;
end;

$$ language plpgsql;

drop function if exists create_account_for_new_user cascade;
create or replace function create_account_for_new_user() returns trigger as
$$
begin
    raise notice 'Creating account for new user %', new.id;
    insert into accountmaster(userid, balance, accountnumber)
    VALUES (new.id, 0.00, gen_random_account_number());
    return new;
end;
$$ language plpgsql;

drop function if exists delete_account_for_user cascade;
create or replace function delete_account_for_user(
    p_account_number varchar,
    p_user_id varchar
) returns void as
$$
begin
    delete
    from accountmaster
    where accountnumber = p_account_number
      and userid = p_user_id;
end;
$$ language plpgsql;

drop function if exists update_account_for_user cascade;
create or replace function update_account_for_user(
    p_account_number varchar,
    p_user_id varchar,
    p_name varchar
) returns void as
$$
begin
    update accountmaster
    set name = p_name
    where accountnumber = p_account_number
      and userid = p_user_id;
end;
$$ language plpgsql;

drop function if exists list_accounts_for_user cascade;
create or replace function list_accounts_for_user(
    p_user_id varchar
)
    returns setof accountpayload
as
$$
begin
    return query
        select a.name, a.balance, a.accountnumber, a.userid, a.updatedat, false
        from accountmaster a
        where a.userid = p_user_id
        order by a.updatedat desc;
end;
$$ language plpgsql;

drop function if exists recompute_account_balance cascade;
create or replace function recompute_account_balance()
    returns trigger as
$$
declare
    account_balance      numeric;
    total_expense_amount numeric;
    total_income_amount  numeric;
begin
    select coalesce(sum(t.amount), 0)
    from transactionmaster t
    where t.accountid = new.accountid
      and t.type = 'DEBIT'
    into total_expense_amount;
    raise notice 'Total expense amount: %', total_expense_amount;
    select coalesce(sum(t.amount), 0)
    from transactionmaster t
    where t.accountid = new.accountid
      and t.type = 'CREDIT'
    into total_income_amount;
    raise notice 'Total income amount: %', total_income_amount;

    account_balance := total_income_amount - total_expense_amount;
    raise notice 'Account balance: %', account_balance;

    update accountmaster
    set balance = account_balance
    where id = new.accountid;
    return new;
end;
$$ language plpgsql;

drop function if exists create_transaction_when_balance_is_non_zero cascade;
create or replace function create_transaction_when_balance_is_non_zero()
    returns trigger as
$$
declare
    category_id varchar;
begin
    if new.balance <> 0 then
        select c.id
        from transactioncategorymaster c
        where c.userid = new.userid
          and c.name = 'General'
        limit 1
        into category_id;

        if category_id is null then
            raise exception 'Category % does not exist', 'General';
        end if;

        insert into transactionmaster(userid, accountid, categoryid, type, amount, description, lasteditby, referencenumber)
        values (new.userid, new.id, category_id, 'CREDIT', new.balance, 'Initial balance', new.userid, gen_random_transaction_ref_number());
    end if;
    return new;
end;
$$ language plpgsql;

drop function if exists notify_accounts cascade;
create or replace function notify_accounts() returns trigger as
$$
declare
    user_id varchar;
    payload accountpayload;
begin
    if tg_op = 'DELETE' then
        select u.id
        from usermaster u
        where u.id = old.userid
        limit 1
        into user_id;

        if user_id is null then
            raise exception 'User % does not exist', old.userid;
        end if;

        select old.name, old.balance, old.accountnumber, old.userid, old.updatedat, true
        into payload;
    else
        select u.id
        from usermaster u
        where u.id = new.userid
        limit 1
        into user_id;

        if user_id is null then
            raise exception 'User % does not exist', new.userid;
        end if;

        select new.name, new.balance, new.accountnumber, new.userid, new.updatedat, false
        into payload;
    end if;

    perform pg_notify('accounts', row_to_json(payload)::text);
    return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_update_updated_at_column on public.accountmaster cascade;
create or replace trigger trigger_update_updated_at_column
    before update
    on accountmaster
    for each row
execute function update_updated_at_column();

drop trigger if exists trigger_create_transaction_when_balance_is_non_zero on public.accountmaster cascade;
create or replace trigger trigger_create_transaction_when_balance_is_non_zero
    after insert
    on accountmaster
    for each row
execute function create_transaction_when_balance_is_non_zero();

drop trigger if exists trigger_notify_accounts on accountmaster cascade;
create or replace trigger trigger_notify_accounts
    after insert or update or delete
    on accountmaster
    for each row
execute function notify_accounts();
