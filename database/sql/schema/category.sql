drop table if exists CategoryPayload cascade;
create table if not exists CategoryPayload
(
    id          varchar not null,
    name        varchar not null,
    description text not null,
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

    insert into transactioncategorymaster(name, description, userid)
    values ('General', 'All general transactions', new.id);

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