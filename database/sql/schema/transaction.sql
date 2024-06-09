drop table if exists TransactionPayload cascade;
create table TransactionPayload
(
    id               varchar primary key not null,
    user_id          varchar             not null,
    account_number   varchar             not null,
    account_name     varchar             not null,
    category_id      varchar             not null,
    type             varchar             not null,
    amount           numeric(10, 2)      not null,
    description      text                not null,
    reference_number varchar             not null,
    status           varchar             not null,
    updated_at       timestamptz                  default now(),
    is_deleted       boolean             not null default false
);

drop function if exists create_transaction cascade;
create or replace function create_transaction(
    p_user_id varchar,
    p_account_number varchar,
    p_category_id varchar,
    p_type varchar,
    p_amount numeric,
    p_description varchar
) returns void as
$$
declare
    account_id  varchar;
    category_id varchar;
begin
    select a.id
    from accountmaster a
    where a.accountnumber = p_account_number
    limit 1
    into account_id;

    if account_id is null then
        raise exception 'Account % does not exist', p_account_number;
    end if;

    select c.id
    from transactioncategorymaster c
    where c.id = p_category_id
    limit 1
    into category_id;

    if category_id is null then
        raise exception 'Category % does not exist', p_category_id;
    end if;

    insert into transactionmaster(userid, accountid, categoryid, type, amount, description, lasteditby, referencenumber)
    values (p_user_id, account_id, category_id, p_type, p_amount, p_description, p_user_id, gen_random_transaction_ref_number());
end;
$$ language plpgsql;

drop function if exists account_to_account_transfer cascade;
create or replace function account_to_account_transfer(
    p_user_id varchar,
    p_from_account_number varchar,
    p_to_account_number varchar,
    p_amount numeric,
    p_description varchar
) returns void as
$$
declare
    from_account_id  varchar;
    to_account_id    varchar;
    category_id      varchar;
    from_description varchar;
    to_description   varchar;
    user_exists      bool = false;
begin
    select exists(select 1 from usermaster where id = p_user_id) into user_exists;
    if not user_exists then
        raise exception 'User % does not exist', p_user_id;
    end if;

    if p_amount <= 0 then
        raise exception 'Amount must be greater than 0';
    end if;

    if p_to_account_number = p_from_account_number then
        raise exception 'Cannot transfer to the same account';
    end if;

    select a.id
    from accountmaster a
    where a.accountnumber = p_from_account_number
    limit 1
    into from_account_id;
    select a.id
    from accountmaster a
    where a.accountnumber = p_to_account_number
    limit 1
    into to_account_id;

    if from_account_id is null or to_account_id is null then
        raise exception 'One or both of the accounts do not exist';
    end if;

    select c.id
    from transactioncategorymaster c
    where c.userid = p_user_id
      and c.name = 'General'
    limit 1
    into category_id;

    if category_id is null then
        raise exception 'Category % does not exist', 'General';
    end if;

    if p_description is null or p_description = '' then
        to_description := 'Transfer to ' || p_to_account_number;
    else
        to_description := p_description;
    end if;

    insert into transactionmaster(userid, accountid, categoryid, type, amount, description, lasteditby, referencenumber)
    values (p_user_id, from_account_id, category_id, 'DEBIT', p_amount, to_description, p_user_id, gen_random_transaction_ref_number());

    if p_description is null or p_description = '' then
        from_description := 'Transfer from ' || p_from_account_number;
    else
        from_description := p_description;
    end if;

    insert into transactionmaster(userid, accountid, categoryid, type, amount, description, lasteditby, referencenumber)
    values (p_user_id, to_account_id, category_id, 'CREDIT', p_amount, from_description, p_user_id, gen_random_transaction_ref_number());
end;

$$
    language plpgsql;

drop function if exists delete_transaction cascade;
create or replace function delete_transaction(
    p_transaction_id varchar,
    p_user_id varchar
) returns void as
$$
declare
    user_exists bool = false;
begin
    select exists(select 1 from usermaster where id = p_user_id) into user_exists;
    if not user_exists then
        raise exception 'User % does not exist', p_user_id;
    end if;

    delete
    from transactionmaster
    where id = p_transaction_id
      and userid = p_user_id;
end;
$$ language plpgsql;

drop function if exists update_transaction cascade;
create or replace function update_transaction(
    p_transaction_id varchar,
    p_user_id varchar,
    p_account_number varchar,
    p_category_id varchar,
    p_type varchar,
    p_amount numeric,
    p_description varchar
) returns void as
$$
declare
    account_id  varchar;
    user_exists bool = false;
begin
    select exists(select 1 from usermaster where id = p_user_id) into user_exists;
    if not user_exists then
        raise exception 'User % does not exist', p_user_id;
    end if;

    select a.id
    from accountmaster a
    where a.accountnumber = p_account_number
    limit 1
    into account_id;

    if account_id is null then
        raise exception 'Account % does not exist', p_account_number;
    end if;

    update transactionmaster
    set accountid   = account_id,
        categoryid  = p_category_id,
        type        = p_type,
        amount      = p_amount,
        description = p_description
    where id = p_transaction_id
      and userid = p_user_id;
end;
$$ language plpgsql;

drop function if exists get_transaction_by_id cascade;
create or replace function get_transaction_by_id(
    p_transaction_id varchar,
    p_user_id varchar
) returns setof transactionpayload as
$$
declare
    transaction_exists bool = false;
    user_exists        bool = false;
begin
    select exists(select 1 from transactionmaster where id = p_transaction_id and userid = p_user_id) into transaction_exists;
    if not transaction_exists then
        raise exception 'Transaction % does not exist', p_transaction_id;
    end if;

    select exists(select 1 from usermaster where id = p_user_id) into user_exists;
    if not user_exists then
        raise exception 'User % does not exist', p_user_id;
    end if;

    return query
        select t.id,
               t.userid,
               a.accountnumber,
               a.name,
               t.categoryid,
               t.type,
               t.amount,
               t.description,
               t.referencenumber,
               t.status,
               t.updatedat,
               false
        from transactionmaster t
                 left join accountmaster a on t.accountid = a.id
        where t.id = p_transaction_id
          and t.userid = p_user_id;
end;
$$ language plpgsql;

drop function if exists list_transactions_for_user cascade;
create or replace function list_transactions_for_user(
    p_user_id varchar,
    p_start_date timestamp,
    p_end_date timestamp,
    p_page_number int,
    p_page_size int
)
    returns setof transactionpayload
as
$$
begin
    if p_page_number < 1 then
        raise exception 'Page number must be greater than 0';
    end if;

    if p_page_size < 1 then
        raise exception 'Page size must be greater than 0';
    end if;

    if p_start_date is null then
        p_start_date := now() - interval '91 days';
    end if;

    if p_end_date is null then
        p_end_date := now();
    end if;

    return query
        select t.id,
               t.userid,
               a.accountnumber,
               a.name,
               t.categoryid,
               t.type,
               t.amount,
               t.description,
               t.referencenumber,
               t.status,
               t.updatedat,
               false
        from transactionmaster t
                 left join accountmaster a on t.accountid = a.id
        where t.userid = p_user_id
          and t.updatedat between p_start_date and p_end_date
        order by updatedat desc
        limit p_page_size offset (p_page_number - 1) * p_page_size;
end;
$$ language plpgsql;

drop function if exists list_transactions_for_user_by_type cascade;
create or replace function list_transactions_for_user_by_type(
    p_user_id varchar,
    p_type varchar,
    p_start_date timestamp,
    p_end_date timestamp,
    p_page_number int,
    p_page_size int
)
    returns setof transactionpayload
as
$$
begin
    if p_page_number < 1 then
        raise exception 'Page number must be greater than 0';
    end if;

    if p_page_size < 1 then
        raise exception 'Page size must be greater than 0';
    end if;

    if p_start_date is null then
        p_start_date := now() - interval '91 days';
    end if;

    if p_end_date is null then
        p_end_date := now();
    end if;

    return query
        select t.id,
               t.userid,
               a.accountnumber,
               a.name,
               t.categoryid,
               t.type,
               t.amount,
               t.description,
               t.referencenumber,
               t.status,
               t.updatedat,
               false
        from transactionmaster t
                 left join accountmaster a on t.accountid = a.id
        where t.userid = p_user_id
          and t.updatedat between p_start_date and p_end_date
          and t.type = p_type
        order by updatedat desc
        limit p_page_size offset (p_page_number - 1) * p_page_size;
end;
$$ language plpgsql;

drop function if exists list_transactions_for_user_by_category cascade;
create or replace function list_transactions_for_user_by_category(
    p_user_id varchar,
    p_category_id varchar,
    p_start_date timestamp,
    p_end_date timestamp,
    p_page_number int,
    p_page_size int
)
    returns setof transactionpayload
as
$$
declare
    category_exists bool = false;
begin
    if p_page_number < 1 then
        raise exception 'Page number must be greater than 0';
    end if;

    if p_page_size < 1 then
        raise exception 'Page size must be greater than 0';
    end if;

    if p_start_date is null then
        p_start_date := now() - interval '91 days';
    end if;

    if p_end_date is null then
        p_end_date := now();
    end if;

    select exists(select 1 from transactioncategorymaster where id = p_category_id and userid = p_user_id) into category_exists;
    if not category_exists then
        raise exception 'Category % does not exist', p_category_id;
    end if;

    return query
        select t.id,
               t.userid,
               a.accountnumber,
               a.name,
               t.categoryid,
               t.type,
               t.amount,
               t.description,
               t.referencenumber,
               t.status,
               t.updatedat,
               false
        from transactionmaster t
                 left join accountmaster a on t.accountid = a.id
        where t.userid = p_user_id
          and t.updatedat between p_start_date and p_end_date
          and t.categoryid = p_category_id
        order by updatedat desc
        limit p_page_size offset (p_page_number - 1) * p_page_size;
end;
$$ language plpgsql;

drop function if exists list_transactions_for_user_by_account cascade;
create or replace function list_transactions_for_user_by_account(
    p_user_id varchar,
    p_account_number varchar,
    p_start_date timestamp,
    p_end_date timestamp,
    p_page_number int,
    p_page_size int
) returns setof transactionpayload
as
$$
declare
    account_id varchar;
begin
    select a.id
    from accountmaster a
    where a.accountnumber = p_account_number
    limit 1
    into account_id;

    if account_id is null then
        raise exception 'Account % does not exist', p_account_number;
    end if;

    if p_page_number < 1 then
        raise exception 'Page number must be greater than 0';
    end if;

    if p_page_size < 1 then
        raise exception 'Page size must be greater than 0';
    end if;

    if p_start_date is null then
        p_start_date := now() - interval '91 days';
    end if;

    if p_end_date is null then
        p_end_date := now();
    end if;

    return query
        select t.id,
               t.userid,
               a.accountnumber,
               a.name,
               t.categoryid,
               t.type,
               t.amount,
               t.description,
               t.referencenumber,
               t.status,
               t.updatedat,
               false
        from transactionmaster t
                 left join accountmaster a on t.accountid = a.id
        where t.userid = p_user_id
          and t.updatedat between p_start_date and p_end_date
          and a.accountnumber = p_account_number
        order by updatedat desc
        limit p_page_size offset (p_page_number - 1) * p_page_size;
end;
$$ language plpgsql;

drop function if exists list_transactions_for_user_by_goal cascade;
create or replace function list_transactions_for_user_by_goal(
    p_user_id varchar,
    p_goal_id varchar,
    p_start_date timestamp,
    p_end_date timestamp,
    p_page_number int,
    p_page_size int
) returns setof transactionpayload
as
$$
declare
    goal_id varchar;
begin
    select a.id
    from goalmaster a
    where a.id = p_goal_id
    limit 1
    into goal_id;

    if goal_id is null then
        raise exception 'Goal % does not exist', p_goal_id;
    end if;

    if p_page_number < 1 then
        raise exception 'Page number must be greater than 0';
    end if;

    if p_page_size < 1 then
        raise exception 'Page size must be greater than 0';
    end if;

    if p_start_date is null then
        p_start_date := now() - interval '91 days';
    end if;

    if p_end_date is null then
        p_end_date := now();
    end if;

    return query
        select t.id,
               t.userid,
               a.accountnumber,
               a.name,
               t.categoryid,
               t.type,
               t.amount,
               t.description,
               t.referencenumber,
               t.status,
               t.updatedat,
               false
        from transactionmaster t
                 left join accountmaster a on t.accountid = a.id
        where t.userid = p_user_id
          and t.referencenumber = p_goal_id
          and t.updatedat between p_start_date and p_end_date
        order by updatedat desc
        limit p_page_size offset (p_page_number - 1) * p_page_size;
end;
$$ language plpgsql;

drop function if exists contribute_to_goal cascade;
create or replace function contribute_to_goal(
    p_user_id varchar,
    p_goal_id varchar,
    p_amount numeric,
    p_description varchar,
    p_account_number varchar
) returns varchar as
$$
declare
    category_id    varchar;
    account_id     varchar;
    goal_exists    boolean = false;
    transaction_id varchar;
begin
    if p_amount <= 0 then
        raise exception 'Amount must be greater than 0';
    end if;

    select c.id
    from transactioncategorymaster c
    where c.userid = p_user_id
      and c.name = 'Goals'
    limit 1
    into category_id;

    if category_id is null then
        raise exception 'Category % does not exist', 'Goals';
    end if;

    select a.id
    from accountmaster a
    where a.userid = p_user_id
      and a.accountnumber = p_account_number
    limit 1
    into account_id;

    if account_id is null then
        raise exception 'Account does not exist';
    end if;

    select exists(select 1 from goalmaster g where g.id = p_goal_id and g.userid = p_user_id) into goal_exists;

    if goal_exists = false then
        raise exception 'Goal % does not exist', p_goal_id;
    end if;

    insert into transactionmaster(userid, categoryid, type, amount, description, lasteditby, accountid, referencenumber)
    values (p_user_id, category_id, 'DEBIT', p_amount, p_description, p_user_id, account_id, gen_random_transaction_ref_number());

    insert into transactionmaster(userid, categoryid, type, amount, description, lasteditby, accountid, referencenumber)
    values (p_user_id, category_id, 'CREDIT', p_amount, p_description, p_user_id, account_id, p_goal_id)
    returning id into transaction_id;

    return transaction_id;
end;
$$ language plpgsql;

drop function if exists notify_transactions cascade;
create or replace function notify_transactions() returns trigger as
$$
declare
    user_id        varchar;
    account_number varchar;
    account_name   varchar;
    payload        transactionpayload;
begin
    if tg_op = 'DELETE' then
        select old.userid, a.accountnumber, a.name
        from accountmaster a
        where a.id = old.accountid
        limit 1
        into user_id, account_number, account_name;

        if user_id is not null and account_number is not null then
            select old.id,
                   user_id,
                   account_number,
                   account_name,
                   old.categoryid,
                   old.type,
                   old.amount,
                   old.description,
                   old.referencenumber,
                   old.status,
                   old.updatedat,
                   true
            into payload;
        end if;
    else
        select new.userid, a.accountnumber
        from accountmaster a
        where a.id = new.accountid
        limit 1
        into user_id, account_number;

        if user_id is not null and account_number is not null then
            select new.id,
                   user_id,
                   account_number,
                   account_name,
                   new.categoryid,
                   new.type,
                   new.amount,
                   new.description,
                   new.referencenumber,
                   new.status,
                   new.updatedat,
                   false
            into payload;
        end if;
    end if;

    perform pg_notify('transactions', row_to_json(payload)::text);
    return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_update_updated_at_column on transactionmaster cascade;
create or replace trigger trigger_update_updated_at_column
    before update
    on transactionmaster
    for each row
execute function update_updated_at_column();

drop trigger if exists trigger_recompute_account_balance on transactionmaster cascade;
create or replace trigger trigger_recompute_account_balance
    after insert
    on transactionmaster
    for each row
execute function recompute_account_balance();

drop trigger if exists trigger_update_goal_balance on transactionmaster cascade;
create or replace trigger trigger_update_goal_balance
    after insert
    on transactionmaster
    for each row
execute function update_goal_balance();

drop trigger if exists trigger_notify_transactions on transactionmaster cascade;
create or replace trigger trigger_notify_transactions
    after insert or update or delete
    on transactionmaster
    for each row
execute function notify_transactions();
