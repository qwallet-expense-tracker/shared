drop table if exists BeneficiaryPayload cascade;
create table BeneficiaryPayload
(
    id             varchar not null,
    account_number varchar not null,
    name           varchar not null,
    description    text not null,
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
