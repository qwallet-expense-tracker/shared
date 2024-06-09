-- create user and grant privileges to database
-- create user quabynah with password 'YS8rUSINtLMTWi8y';
grant all privileges on database postgres to quabynah;

create extension if not exists pgcrypto;

create sequence if not exists qwallet_table_seq;

create or replace function gen_random_shard_id() returns bigint as
$$
declare
    predefined_epoch bigint := 1711547046470; -- 27/03/2024
    seq_id           bigint;
    now_millis       bigint := floor(extract(epoch from clock_timestamp()) * 1000);
    shard_id         int    := 5;
    result           bigint;
begin
    seq_id := nextval('public.qwallet_table_seq');
    result := (now_millis - predefined_epoch) << 23;
    result := result | (shard_id << 10);
    result := result | (seq_id & 1023);
    return result;
end;
$$ language plpgsql;

create or replace function gen_random_qwallet_id() returns bigint as
$$
declare
    predefined_epoch bigint := 1711835175903; -- 30/03/2024
    seq_id           bigint;
    now_millis       bigint := floor(extract(epoch from clock_timestamp()) * 1000);
    shard_id         int    := 5;
    result           bigint;
begin
    seq_id := nextval('public.qwallet_table_seq');
    result := (now_millis - predefined_epoch) << 23;
    result := result | (shard_id << 10);
    result := result | (seq_id & 1023);
    return result;
end;
$$ language plpgsql;

create or replace function gen_random_account_number() returns varchar as
$$
declare
    p_account_number varchar;
begin
    select 'QW-AC-' || lpad(cast(floor(random() * 1000000000) as text), 16, '0')
    into p_account_number;
    return p_account_number;
end;
$$ language plpgsql;

create or replace function gen_random_qwallet_transaction_id() returns bigint as
$$
declare
    predefined_epoch bigint := 1711835175903; -- 30/03/2024
    seq_id           bigint;
    now_millis       bigint := floor(extract(epoch from clock_timestamp()) * 1000);
    shard_id         int    := 5;
    result           bigint;
begin
    seq_id := nextval('public.qwallet_table_seq');
    result := (now_millis - predefined_epoch) << 23;
    result := result | (shard_id << 10);
    result := result | (seq_id & 1023);
    return result;
end;
$$ language plpgsql;

create or replace function gen_random_transaction_ref_number() returns varchar as
$$
declare
    p_transaction_id varchar;
begin
    select 'QWT-REF-' || lpad(cast(floor(random() * 1000000000) as text), 23, '0')
    into p_transaction_id;
    return p_transaction_id;
end;
$$ language plpgsql;

create or replace function update_updated_at_column()
    returns trigger as
$$
begin
    new.updatedat := now();
    return new;
end;
$$ language plpgsql;

-- user table (stores basic user information - needed for authentication)
create table if not exists UserMaster
(
    TID          bigint       not null   default gen_random_shard_id(),
    ID           varchar(36) primary key default gen_random_qwallet_id(),
    Name         varchar(255) not null   default 'Anonymous',
    Email        varchar(255) not null unique,
    PhoneNumber  varchar(15)             default null,
    AuthID       varchar                 default null, -- token from auth ID
    PasswordHash varchar                 default null, -- biometric hash (PIN/Password/Biometric)
    AvatarUrl    varchar                 default '',   -- biometric hash (PIN/Password/Biometric)
    CreatedAt    timestamptz  not null   default now(),
    UpdatedAt    timestamptz  not null   default now()
);

-- account table (stores account/wallet information - needed for transactions)
create table if not exists AccountMaster
(
    TID           bigint         not null        default gen_random_shard_id(),
    ID            varchar(36) primary key        default gen_random_qwallet_id(),
    UserID        varchar(36)    not null references UserMaster (ID) on delete cascade,
    AccountNumber varchar(255)   not null unique default gen_random_account_number(),
    Balance       numeric(10, 2) not null        default 0.00,
    Name          varchar(255)   not null        default 'Cash on hand',
    CreatedAt     timestamptz    not null        default now(),
    UpdatedAt     timestamptz    not null        default now(),

    -- unique constraint
    constraint unique_account_name unique (Name, UserID)
);
create index if not exists idx_user_id on AccountMaster (UserID);

-- transaction category table
create table if not exists TransactionCategoryMaster
(
    TID         bigint       not null   default gen_random_shard_id(),
    ID          varchar(36) primary key default gen_random_qwallet_id(),
    Name        varchar(255) not null,
    UserID      varchar(36)  not null references UserMaster (ID) on delete cascade,
    Description text         not null,
    CreatedAt   timestamptz  not null   default now(),
    UpdatedAt   timestamptz  not null   default now(),

    -- unique constraint
    constraint unique_category_name unique (Name, UserID)
);
create index if not exists idx_category_name on TransactionCategoryMaster (Name);

-- transaction table (stores transactions (credit/debit) information - needed for account balance update and history)
create table if not exists TransactionMaster
(
    TID             bigint         not null default gen_random_shard_id(),
    ID              varchar(36) primary key default gen_random_qwallet_id(),
    UserID          varchar(36)    not null references UserMaster (ID) on delete cascade,
    AccountID       varchar(36)    not null references AccountMaster (ID) on delete cascade,
    CategoryID      varchar(36)    not null references TransactionCategoryMaster (ID) on delete cascade,
    Amount          numeric(10, 2) not null,
    ReferenceNumber varchar(255)   not null default gen_random_transaction_ref_number(),
    Type            varchar(10)    not null check (Type in ('CREDIT', 'DEBIT')),
    LastEditBy      varchar(36)    not null references UserMaster (ID) on delete cascade,
    Status          varchar(50)    not null default 'PENDING' check (Status in ('PENDING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    Description     text           not null,
    CreatedAt       timestamptz    not null default now(),
    UpdatedAt       timestamptz    not null default now()
);
comment on column TransactionMaster.Amount is 'cannot be negative';
create index if not exists idx_transaction_type on TransactionMaster (Type, AccountID);
create index if not exists idx_transaction_status on TransactionMaster (Status, AccountID);
create index if not exists idx_transaction_category_id on TransactionMaster (CategoryID);
create index if not exists idx_transaction_user_id on TransactionMaster (UserID);
create index if not exists idx_transaction_ref_number on TransactionMaster (ReferenceNumber);


-- beneficiary table (stores beneficiary information - needed for fund transfer)
create table if not exists BeneficiaryMaster
(
    TID         bigint       not null   default gen_random_shard_id(),
    ID          varchar(36) primary key default gen_random_qwallet_id(),
    UserID      varchar(36)  not null references UserMaster (ID) on delete cascade,
    Name        varchar(255) not null,
    AccountID   varchar(36)  not null references AccountMaster (ID) on delete cascade,
    Description text         not null   default 'Beneficiary Account',
    CreatedAt   timestamptz  not null   default now(),
    UpdatedAt   timestamptz  not null   default now()
);
create index if not exists idx_beneficiary_name on BeneficiaryMaster (Name);
create index if not exists idx_beneficiary_user_id on BeneficiaryMaster (UserID);
create index if not exists idx_beneficiary_account_id on BeneficiaryMaster (AccountID);

-- goal table
create table if not exists GoalMaster
(
    TID                   bigint         not null default gen_random_shard_id(),
    ID                    varchar(36) primary key default gen_random_qwallet_id(),
    UserID                varchar(36)    not null references UserMaster (ID) on delete cascade,
    Name                  varchar(255)   not null,
    Target                numeric(10, 2) not null,
    Balance               numeric(10, 2) not null default 0.00,
    Status                varchar(50)    not null default 'PENDING' check (Status in ('PENDING', 'COMPLETED', 'IN_PROGRESS', 'CANCELLED')),
    AmountContributed     numeric(10, 2) not null default 0.00,
    PercentageContributed numeric(5, 2)  not null default 0.00,
    Description           text           not null,
    CreatedAt             timestamptz    not null default now(),
    UpdatedAt             timestamptz    not null default now()
);
create index if not exists idx_goal_name on GoalMaster (Name);
create index if not exists idx_goal_user_id on GoalMaster (UserID);

-- goal trash table
create table if not exists GoalTrashMaster
(
    TID                   bigint         not null default gen_random_shard_id(),
    ID                    varchar(36) primary key default gen_random_qwallet_id(),
    UserID                varchar(36)    not null references UserMaster (ID) on delete cascade,
    Name                  varchar(255)   not null,
    Target                numeric(10, 2) not null,
    Balance               numeric(10, 2) not null default 0.00,
    Status                varchar(50)    not null default 'PENDING' check (Status in ('PENDING', 'COMPLETED', 'IN_PROGRESS', 'CANCELLED')),
    AmountContributed     numeric(10, 2) not null default 0.00,
    PercentageContributed numeric(5, 2)  not null default 0.00,
    Description           text           not null,
    CreatedAt             timestamptz    not null default now(),
    UpdatedAt             timestamptz    not null default now()
);

drop table if exists AccountPayload cascade;
create table if not exists AccountPayload
(
    name           varchar not null,
    balance        numeric not null,
    account_number varchar not null,
    user_id        varchar not null,
    updated_at     timestamptz,
    is_deleted     boolean not null default false
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

-- drop function if exists create_transaction_when_balance_is_non_zero cascade;
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

drop table if exists BeneficiaryPayload cascade;
create table BeneficiaryPayload
(
    id             varchar not null,
    account_number varchar not null,
    name           varchar not null,
    description    text    not null,
    user_id        varchar not null,
    updated_at     timestamptz,
    is_deleted     boolean not null default false
);

drop function if exists create_beneficiary cascade;
create or replace function create_beneficiary(
    p_user_id varchar,
    p_name varchar,
    p_account_number varchar,
    p_description varchar
) returns void as
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

    if exists(select 1 from beneficiarymaster b where b.userid = p_user_id and b.accountid = account_id) then
        raise exception 'Beneficiary for account % already exists', p_account_number;
    end if;

    if p_description is null or p_description = '' then
        p_description := 'Beneficiary for account ' || p_account_number;
    end if;

    insert into beneficiarymaster(userid, accountid, name, description)
    values (p_user_id, account_id, p_name, p_description);
end;
$$ language plpgsql;

drop function if exists delete_beneficiary cascade;
create or replace function delete_beneficiary(
    p_beneficiary_id varchar,
    p_user_id varchar
) returns void as
$$
declare
    beneficiary_exists bool = false;
begin
    select exists(select 1 from beneficiarymaster b where b.id = p_beneficiary_id and b.userid = p_user_id) into beneficiary_exists;
    if not beneficiary_exists then
        raise exception 'Beneficiary % does not exist', p_beneficiary_id;
    end if;

    delete
    from beneficiarymaster
    where id = p_beneficiary_id
      and userid = p_user_id;
end;
$$ language plpgsql;

drop function if exists get_beneficiary cascade;
create or replace function get_beneficiary(
    p_beneficiary_id varchar,
    p_user_id varchar
) returns setof beneficiarypayload as
$$
declare
    beneficiary_exists bool = false;
begin
    select exists(select 1 from beneficiarymaster b where b.id = p_beneficiary_id and b.userid = p_user_id) into beneficiary_exists;
    if not beneficiary_exists then
        raise exception 'Beneficiary % does not exist', p_beneficiary_id;
    end if;

    return query
        select b.id, a.accountnumber, b.name, b.description, b.userid, b.updatedat, false
        from beneficiarymaster b
                 left join accountmaster a on b.accountid = a.id
        where b.id = p_beneficiary_id
          and b.userid = p_user_id;
end;
$$ language plpgsql;

drop function if exists update_beneficiary cascade;
create or replace function update_beneficiary(
    p_beneficiary_id varchar,
    p_user_id varchar,
    p_name varchar,
    p_account_number varchar,
    p_description varchar
) returns void as
$$
declare
    account_id         varchar;
    beneficiary_exists bool = false;
begin
    select exists(select 1 from beneficiarymaster b where b.id = p_beneficiary_id and b.userid = p_user_id) into beneficiary_exists;
    if not beneficiary_exists then
        raise exception 'Beneficiary % does not exist', p_beneficiary_id;
    end if;

    select a.id
    from accountmaster a
    where a.accountnumber = p_account_number
    limit 1
    into account_id;

    if account_id is null then
        raise exception 'Account % does not exist', p_account_number;
    end if;

    update beneficiarymaster
    set name        = p_name,
        accountid   = account_id,
        description = p_description
    where id = p_beneficiary_id
      and userid
        = p_user_id;
end;
$$ language plpgsql;

drop function if exists list_beneficiaries_for_user cascade;
create or replace function list_beneficiaries_for_user(
    p_user_id varchar,
    p_page_number int,
    p_page_size int
)
    returns setof beneficiarypayload as
$$
declare
    user_exists bool = false;
begin
    select exists(select 1 from usermaster u where u.id = p_user_id) into user_exists;
    if not user_exists then
        raise exception 'User % does not exist', p_user_id;
    end if;

    if p_page_number < 1 then
        raise exception 'Page number must be greater than 0';
    end if;

    if p_page_size < 1 then
        raise exception 'Page size must be greater than 0';
    end if;

    return query
        select b.id, a.accountnumber, b.name, b.description, b.userid, b.updatedat, false
        from beneficiarymaster b
                 left join accountmaster a on b.accountid = a.id
        where b.userid = p_user_id
        order by b.updatedat desc
        limit p_page_size offset (p_page_number - 1) * p_page_size;
end;
$$ language plpgsql;

drop function if exists notify_beneficiaries cascade;
create or replace function notify_beneficiaries()
    returns trigger as
$$
declare
    account_id     varchar;
    account_number varchar;
    user_id        varchar;
    payload        beneficiarypayload;
begin
    if tg_op = 'DELETE' then
        select a.id, a.accountnumber
        into account_id, account_number
        from accountmaster a
        where a.id = old.accountid;

        select u.id
        into user_id
        from usermaster u
        where u.id = old.userid;

        if user_id is null then
            raise exception 'User % does not exist', old.userid;
        end if;

        if account_id is null then
            raise exception 'Account % does not exist', account_number;
        end if;

        select old.id, account_number, old.name, old.description, old.userid, old.updatedat, true
        into payload;

    else
        select a.id
        into account_id
        from accountmaster a
        where a.id = new.accountid;

        select u.id
        into user_id
        from usermaster u
        where u.id = new.userid;

        if user_id is null then
            raise exception 'User % does not exist', old.userid;
        end if;

        if account_id is null then
            raise exception 'Account % does not exist', account_number;
        end if;

        select new.id, account_number, new.name, new.description, new.userid, new.updatedat, false
        into payload;
    end if;

    perform pg_notify('beneficiaries', row_to_json(payload)::text);
    return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_update_updated_at_column on beneficiarymaster cascade;
create or replace trigger trigger_update_updated_at_column
    before update
    on beneficiarymaster
    for each row
execute function update_updated_at_column();

drop trigger if exists trigger_notify_beneficiaries on beneficiarymaster cascade;
create or replace trigger trigger_notify_beneficiaries
    after insert or update or delete
    on beneficiarymaster
    for each row
execute function notify_beneficiaries();

drop table if exists CategoryPayload cascade;
create table if not exists CategoryPayload
(
    id          varchar not null,
    name        varchar not null,
    description text    not null,
    user_id     varchar not null,
    is_deleted  boolean not null default false
);

drop function if exists create_category cascade;
create or replace function create_category(
    p_name varchar,
    p_description varchar,
    p_user_id varchar
) returns void as
$$
begin
    insert into transactioncategorymaster(name, description, userid)
    values (p_name, p_description, p_user_id);
end;
$$ language plpgsql;

drop function if exists delete_category cascade;
create or replace function delete_category(
    p_category_id varchar,
    p_user_id varchar
) returns void as
$$
declare
    category_exists bool = false;
begin
    select exists(select 1 from transactioncategorymaster where id = p_category_id) into category_exists;
    if not category_exists then
        raise exception 'Category % does not exist', p_category_id;
    end if;

    delete
    from transactioncategorymaster c
    where c.id = p_category_id
      and c.userid = p_user_id;
end;
$$ language plpgsql;

drop function if exists update_category cascade;
create or replace function update_category(
    p_category_id varchar,
    p_name varchar,
    p_description varchar
) returns void as
$$
declare
    category_exists bool = false;
begin
    select exists(select 1 from transactioncategorymaster where id = p_category_id) into category_exists;
    if not category_exists then
        raise exception 'Category % does not exist', p_category_id;
    end if;

    update transactioncategorymaster
    set name        = p_name,
        description = p_description
    where id = p_category_id;
end;
$$ language plpgsql;

drop function if exists list_categories_for_user cascade;
create or replace function list_categories_for_user(
    p_user_id varchar
)
    returns setof categorypayload
as
$$
begin
    return query
        select c.id, c.name, c.description, c.userid, false
        from transactioncategorymaster c
        where userid = p_user_id
        order by c.updatedat desc;
end;
$$ language plpgsql;

drop function if exists create_categories_for_new_user cascade;
create or replace function create_categories_for_new_user() returns trigger as
$$
begin
    insert into transactioncategorymaster(name, description, userid)
    values ('General', 'All general transactions', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Food', 'All food related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Grocery', 'All grocery related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Rent', 'All rent related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Utilities', 'All utility related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Water', 'All water related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Fuel & Gas', 'All fuel and gas related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Transport', 'All transport related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Clothing', 'All clothing related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Grooming', 'All grooming related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Family Support', 'All support related to your family', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Spousal Support', 'All support related to your spouse/partner', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Home Maintenance', 'All home maintenance related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Shopping', 'All shopping related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Health', 'All health related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Insurance', 'All insurance related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Investment', 'All investment related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Savings', 'All savings related expenses', new.id);

    insert into transactioncategorymaster(name, description, userid)
    values ('Goals', 'Tracks all contributions made towards goals', new.id);

    return new;
end;
$$ language plpgsql;

drop function if exists notify_categories cascade;
create or replace function notify_categories() returns trigger as
$$
declare
    user_id varchar;
    payload categorypayload;
begin
    if tg_op = 'DELETE' then
        select u.id
        into user_id
        from usermaster u
        where u.id = old.userid;

        if user_id is null then
            raise exception 'User % does not exist', old.userid;
        end if;

        select old.id, old.name, old.description, old.userid, true
        into payload;
    else
        select u.id
        into user_id
        from usermaster u
        where u.id = new.userid;

        if user_id is null then
            raise exception 'User % does not exist', new.userid;
        end if;

        select new.id, new.name, new.description, new.userid, false
        into payload;
    end if;

    perform pg_notify('categories', row_to_json(payload)::text);
    return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_update_updated_at_column on transactioncategorymaster cascade;
create or replace trigger trigger_update_updated_at_column
    before update
    on transactioncategorymaster
    for each row
execute function update_updated_at_column();

drop trigger if exists trigger_notify_categories on transactioncategorymaster cascade;
create or replace trigger trigger_notify_categories
    after insert or update or delete
    on transactioncategorymaster
    for each row
execute function notify_categories();

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

drop table if exists UserStats cascade;
create table if not exists UserStats
(
    total_accounts     bigint  not null,
    total_transactions bigint  not null,
    total_categories   bigint  not null,
    total_goals        bigint  not null,
    account_balance    numeric not null,
    account_number     varchar not null,
    total_income       numeric not null,
    total_expense      numeric not null
);

drop table if exists UserPayload cascade;
create table if not exists UserPayload
(
    id           varchar not null,
    email        varchar not null,
    name         varchar not null,
    phone_number varchar not null,
    avatar_url   varchar not null default '',
    is_deleted   boolean not null default false
);

drop function if exists hash_password cascade;
create or replace function hash_password(p_password varchar) returns varchar as
$$
declare
    result varchar;
begin
    select crypt(p_password, gen_salt('bf'))
    into result;
    return result;
end;
$$ language plpgsql;

drop function if exists verify_password cascade;
create or replace function verify_password(p_password varchar, p_hashed_password varchar) returns boolean as
$$
begin
    return crypt(p_password, p_hashed_password) = p_hashed_password;
end;
$$ language plpgsql;

drop function if exists create_user cascade;
create or replace function create_user(
    p_email varchar,
    p_auth_id varchar,
    p_phone_number varchar,
    p_password varchar,
    p_user_name varchar,
    p_avatar_url varchar
)
    returns setof userpayload
as
$$
declare
    exists           boolean := false;
    password_hash    varchar;
    out_user_id      varchar;
    out_email        varchar;
    out_name         varchar;
    out_phone_number varchar;
begin
    select exists(select 1 from usermaster u where u.email = p_email)
    into exists;
    if exists then
        raise exception 'User with email % already exists', p_email;
    else
        if p_password is null or length(p_password) = 0 then
            raise notice 'Password is null, setting default password as empty string';
            p_password := '';
        else
            raise notice 'Hashing password';
            password_hash := hash_password(p_password);
        end if;

        if p_user_name is null or length(p_user_name) = 0 then
            raise notice 'User name cannot be null or empty';
            p_user_name := 'Anonymous User';
        end if;

        insert into usermaster(email, authid, phonenumber, passwordhash, name, avatarurl)
        values (p_email, p_auth_id, p_phone_number, password_hash, p_user_name, p_avatar_url)
        returning id, email, name, phonenumber into out_user_id, out_email, out_name, out_phone_number;
        return query
            select out_user_id, out_email, out_name, out_phone_number, p_avatar_url, false;
    end if;
end;
$$ language plpgsql;

drop function if exists login_user_with_password cascade;
create or replace function login_user_with_password(
    p_user_id varchar,
    p_password varchar
)
    returns setof userpayload
as
$$
declare
    exists        boolean := false;
    password_hash varchar;
begin
    select exists(select 1 from usermaster u where u.id = p_user_id)
    into exists;
    if exists then
        select u.passwordhash
        into password_hash
        from usermaster u
        where u.id = p_user_id
        limit 1;

        if verify_password(p_password, password_hash) then
            return query
                select u.id, u.email, u.name, u.phonenumber, u.avatarurl, false
                from usermaster u
                where u.id = p_user_id
                limit 1;
        else
            raise exception 'Invalid password';
        end if;
    else
        raise exception 'User with id % does not exist', p_user_id;
    end if;

end;
$$ language plpgsql;

drop function if exists login_user cascade;
create or replace function login_user(
    p_auth_id varchar,
    p_email varchar,
    p_name varchar,
    p_phone_number varchar,
    p_avatar_url varchar
)
    returns setof userpayload
as
$$
declare
    user_exists bool = false;
    p_user_id   varchar;
begin
    -- check if user authentication token is passed
    if p_auth_id is null or length(p_auth_id) = 0 then
        raise exception 'Login failed. Auth token is required';
    end if;

    -- check if user already exists
    select exists(select id from usermaster where email = p_email) into user_exists;

    if not user_exists then
        if p_name is null or length(p_name) = 0 then
            raise exception 'Login failed. User display name is required';
        end if;

        insert into usermaster(name, email, authid, phonenumber, avatarurl)
        values (p_name, p_email, p_auth_id, p_phone_number, p_avatar_url)
        returning id into p_user_id;

        return query
            select u.id, u.email, u.name, u.phonenumber, u.avatarurl, false
            from usermaster u
            where u.id = p_user_id
            limit 1;
    end if;

    update usermaster
    set authid = p_auth_id
    where email = p_email;

    if p_avatar_url is not null and length(p_avatar_url) > 0 then
        update usermaster
        set avatarurl = p_avatar_url
        where email = p_email;
    end if;

    return query
        select u.id, u.email, u.name, u.phonenumber, u.avatarurl, false
        from usermaster u
        where u.email = p_email
          and u.authid = p_auth_id
        limit 1;
end;
$$ language plpgsql;

drop function if exists get_user_by_email cascade;
create or replace function get_user_by_email(
    p_email varchar
)
    returns setof userpayload
as
$$
begin
    return query
        select u.id, u.email, u.name, u.phonenumber, u.avatarurl, false
        from usermaster u
        where u.email = p_email
        limit 1;
end;
$$ language plpgsql;

drop function if exists get_user_by_id cascade;
create or replace function get_user_by_id(
    p_user_id varchar
) returns setof userpayload
as
$$
begin
    return query
        select u.id, u.email, u.name, u.phonenumber, u.avatarurl, false
        from usermaster u
        where u.id = p_user_id
        limit 1;
end;
$$ language plpgsql;

drop function if exists create_password cascade;
create or replace function create_password(
    p_user_id varchar,
    p_password varchar
)
    returns void
as
$$
declare
    password_hash varchar;
begin
    if p_password is null or length(p_password) = 0 then
        raise exception 'Password cannot be null or empty';
    else
        raise notice 'Hashing password';
        password_hash := hash_password(p_password);
    end if;

    update usermaster
    set passwordhash = password_hash
    where id = p_user_id;

end;
$$ language plpgsql;

drop function if exists revoke_password cascade;
create or replace function revoke_password(
    p_user_id varchar
)
    returns void
as
$$
begin
    update usermaster
    set passwordhash = null
    where id = p_user_id;
end;
$$ language plpgsql;

drop function if exists list_users cascade;
create or replace function list_users()
    returns setof userpayload
as
$$
begin
    return query
        select u.id, u.email, u.name, u.phonenumber, u.avatarurl, false
        from usermaster u;
end;
$$ language plpgsql;

drop function if exists update_user cascade;
create or replace function update_user(
    p_user_id varchar,
    p_name varchar,
    p_phone_number varchar,
    p_avatar_url varchar
)
    returns setof userpayload
as
$$
declare
    exists  boolean := false;
    p_email varchar;
begin
    select exists(select 1 from usermaster u where u.id = p_user_id)
    into exists;
    if exists then
        update usermaster
        set name        = p_name,
            phonenumber = p_phone_number,
            avatarurl   = p_avatar_url
        where id = p_user_id
        returning id, email, name, phonenumber, avatarurl
            into p_user_id, p_email, p_name, p_phone_number, p_avatar_url;
        return query
            select p_user_id, p_email, p_name, p_phone_number, p_avatar_url, false;
    else
        raise exception 'User with id % does not exist', p_user_id;
    end if;
end;
$$ language plpgsql;

drop function if exists delete_user_data cascade;
create or replace function delete_user_data() returns trigger as
$$
begin
    delete
    from transactionmaster
    where userid = old.id;
    delete
    from transactioncategorymaster
    where userid = old.id;
    delete
    from goalmaster
    where userid = old.id;
    delete
    from accountmaster
    where userid = old.id;
    return old;
end;
$$ language plpgsql;

drop function if exists get_user_stats cascade;
create or replace function get_user_stats(
    p_user_email varchar
)
    returns setof userstats
as
$$
declare
    user_id varchar;
begin
    select u.id
    from usermaster u
    where u.email = p_user_email
    limit 1
    into user_id;

    if user_id is null then
        raise exception 'User % does not exist', p_user_email;
    end if;

    return query
        select (select count(*) from accountmaster a where a.userid = user_id)                                             as total_accounts,
               (select count(*) from transactionmaster t where t.userid = user_id)                                         as total_transactions,
               (select count(*) from transactioncategorymaster c where c.userid = user_id)                                 as total_categories,
               (select count(*) from goalmaster g where g.userid = user_id)                                                as total_goals,
               (select coalesce(sum(a.balance), 0) from accountmaster a where a.userid = user_id)                          as total_account_balance,
               (select a.accountnumber from accountmaster a where a.userid = user_id limit 1)                              as account_number,
               (select coalesce(sum(t.amount), 0) from transactionmaster t where t.userid = user_id and t.type = 'CREDIT') as total_income,
               (select coalesce(sum(t.amount), 0) from transactionmaster t where t.userid = user_id and t.type = 'DEBIT')  as total_expenses;
end;

$$ language plpgsql;

drop trigger if exists trigger_create_account_for_new_user on usermaster cascade;
create or replace trigger trigger_create_account_for_new_user
    after insert
    on usermaster
    for each row
execute function create_account_for_new_user();

drop trigger if exists trigger_delete_user_data on usermaster cascade;
create or replace trigger trigger_delete_user_data
    after delete
    on usermaster
    for each row
execute function delete_user_data();

drop trigger if exists trigger_create_default_categories on usermaster cascade;
create or replace trigger trigger_create_default_categories
    after insert
    on usermaster
    for each row
execute function create_categories_for_new_user();

drop trigger if exists trigger_update_updated_at_column on usermaster cascade;
create or replace trigger trigger_update_updated_at_column
    before update
    on usermaster
    for each row
execute function update_updated_at_column();
