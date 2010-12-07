
CREATE FUNCTION inline_0 ()
RETURNS integer AS '
begin
    PERFORM acs_object_type__create_type (
        ''radio_container'',    -- object_type
        ''Radio Container'',    -- pretty_name
        ''Radio Containers'',   -- pretty_plural
        ''acs_object'',         -- supertype
        ''radio_containers'',   -- table_name
        ''container_id'',         -- id_column
        null,                   -- package_name
        ''f'',                  -- abstract_p
        null,                   -- type_extension_table
        null                    -- name_method
    );

    return 0;
end;' LANGUAGE 'plpgsql';

SELECT inline_0 (); 

DROP FUNCTION inline_0 ();


create table radio_containers (
        container_id    int primary key references acs_objects(object_id),
        
        name            varchar(255) not null,

        -- a group that contains the editors for this container.
        -- will be granted special permissions on this container.
        editors_group_id        integer references groups(group_id),

        -- all single contributor groups of the programs are
        -- components of this container contributor group. direct
        -- members are individuals that are associated to this
        -- container but have no concrete show yet.
        contributors_group_id   integer references groups(group_id),

        -- an optional url that represents this container (not 
        -- sure how to use that)
        url             varchar(4000),

        -- an html color value, e.g. '#eeeeee' or 'red' that should
        -- be used to display this container.
        color           varchar(50),

        short_desc varchar(4000),
        long_desc text,
        long_desc_format varchar(200),

        internal_comments text,

        start_date      date,
        end_date        date,

        active_p        boolean not null default 't'
);


-- Manifestations of the container on a specific point in time.

create sequence radio_container_instances_seq;

create table radio_container_instances (
    instance_id     integer primary key default nextval('radio_container_instances_seq'),
    container_id    integer not null references radio_containers,
    start_date      timestamptz not null,  
    end_date        timestamptz not null,

    constraint chk_radio_container_instance_date check (end_date > start_date)

);


-- Create a new container. Maybe this would be better in a tcl proc ...
CREATE FUNCTION radio_container__new(integer,varchar,varchar,varchar,varchar,text,varchar,text,timestamptz,timestamptz,boolean,integer,integer,varchar)

RETURNS integer AS '
declare
        p_container_id  alias for $1;   -- default null
        p_name          alias for $2;
        p_url           alias for $3;   -- default null
        p_color         alias for $4;
        p_short_desc    alias for $5;
        p_long_desc     alias for $6;
        p_long_desc_format    alias for $7;
        p_internal_comments   alias for $8;
        p_start_date    alias for $9;   -- default now()
        p_end_date      alias for $10;   -- default null
        p_create_editors_group_p alias for $11;
        p_context_id    alias for $12;   -- default null
        p_creation_user alias for $13;  -- default null
        p_creation_ip   alias for $14;  -- default null
        v_container_id    integer;
        v_recurring_set_id    integer;
        v_main_editors_group_id integer;
        v_group_id      integer;
begin

        v_container_id := acs_object__new (
                p_container_id,
                ''radio_container'',
                now(),
                p_creation_user,
                p_creation_ip,
                p_context_id
        );

        insert into radio_containers 
          (container_id, name, url, color, short_desc, long_desc, long_desc_format, internal_comments, start_date, end_date, active_p)
        values 
          (v_container_id, p_name, p_url, p_color, p_short_desc, p_long_desc, p_long_desc_format, p_internal_comments, p_start_date, p_end_date, ''t'');


        -- create editors group. set context_id to the same as the container''s context_id,
        -- which is supposed to be the radio-management package.
        if p_create_editors_group_p then
                v_group_id := acs_group__new(
                        null,
                        ''group'',
                        now(),
                        p_creation_user,
                        p_creation_ip,
                        null,
                        null,
                        p_name || '' Editors'',
                        ''needs approval'',
                        p_context_id -- context_id
                );
                update radio_containers set editors_group_id=v_group_id
                        where container_id=v_container_id;
        
                perform acs_permission__grant_permission (
                        v_container_id,
                        v_group_id,
                        ''write''
                );

                perform acs_permission__grant_permission (
                        v_container_id,
                        v_group_id,
                        ''create''
                );

                -- make this new group a part of the main ''Editors'' group
                select editors_group_id into v_main_editors_group_id from
                        radio_magic_group_ids limit 1;
                perform composition_rel__new (
                        v_main_editors_group_id,
                        v_group_id
                );
        end if;

    return v_container_id;    
end;
' language 'plpgsql';



CREATE FUNCTION radio_container__delete(integer)

RETURNS integer AS '
declare
        p_container_id  alias for $1;   -- default null
        v_editors_group_id integer;
begin

        select editors_group_id into v_editors_group_id from radio_containers
        where container_id=p_container_id;

        perform acs_group__delete(v_editors_group_id);

        delete from radio_containers where container_id=p_container_id;

        perform acs_object__delete (p_container_id);

    return 0;
end;
' language 'plpgsql';
