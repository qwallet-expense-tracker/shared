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

        insert into usermaster(name, email, authid, phonenumber)
        values (p_name, p_email, p_auth_id, p_phone_number)
        returning id into p_user_id;

        return query
            select u.id, u.email, u.name, u.phonenumber, u.avatarurl, false
            from usermaster u
            where u.email = p_email
              and u.id = p_user_id
            limit 1;
    end if;

    update usermaster
    set authid    = p_auth_id,
        avatarurl = p_avatar_url
    where email = p_email;

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