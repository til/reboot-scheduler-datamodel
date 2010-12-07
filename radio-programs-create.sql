
CREATE FUNCTION inline_0 ()
RETURNS integer AS '
begin
    PERFORM acs_object_type__create_type (
        ''radio_program'',      -- object_type
        ''Radio Program'',      -- pretty_name
        ''Radio Programs'',     -- pretty_plural
        ''acs_object'',         -- supertype
        ''radio_programs'',     -- table_name
        ''program_id'',         -- id_column
        null,                   -- package_name
        ''f'',                  -- abstract_p
        null,                   -- type_extension_table
        null                    -- name_method
    );

    PERFORM acs_object_type__create_type (
       ''radio_group'',
       ''Radio Group'',
       ''Radio Groups'',
       ''group'',
       ''RADIO_GROUP_EXT'',
       ''GROUP_ID'',
       null,
       ''f'',
       null,
       null
    );

    return 0;
end;' LANGUAGE 'plpgsql';

SELECT inline_0 (); 

DROP FUNCTION inline_0 ();

create sequence radio_category_id_seq;
create table radio_categories (
        category_id     integer not null primary key default nextval('radio_category_id_seq'),
        category varchar(255) not null,
        icon_url varchar(255)
);


create table radio_programs (
        program_id int primary key references acs_objects(object_id) on delete cascade,

        -- does not need to be unique - deleted programs would get in the
        -- way otherwise
        name varchar(255),

        -- the container that this program is associated to, can be null
        container_id    integer references radio_containers(container_id),

        category_id integer references radio_categories(category_id),
        
        -- where this programs home page is mounted
        url varchar(255),

        internal_comments text,

        -- when does this program start?
        start_date timestamp,

        -- When it ends. Null if end not determined.
        end_date timestamp,

        -- until when radio_emissions has been pre-populated
        db_populated_until date,

        -- this program's contributors group
        contributors_group_id integer,

        -- a forums.forum_id for this program
        forum_id integer,

        -- does this program recur regulary? f when sondersendung etc. 
        recurring_p boolean default 't',

        -- If this program is currently active. Means it will be
        -- listed. Should be (but isn't currently) set to f automatically
        -- when end_date < now.
        active_p boolean default 't',


        -- dublin core specific fields

        dc__description__abstract       text,
        dc__description__long   text,
        dc_description_long_format      varchar(100),

        -- dc__type is possibly deprecated, should be the associated
        -- container now
        dc__type                varchar(1000),

        dc__language            char(3),
        
        dc__coverage__spatial   varchar(1000),
        dc__coverage__temporal  varchar(1000)

);


create view radio_programs_displayable as
select * from radio_programs where active_p='t' and recurring_p='t';




CREATE FUNCTION radio_program__new(integer,varchar,integer,integer,timestamptz,timestamptz,varchar,text,varchar,varchar,varchar,varchar,varchar,boolean,integer,integer,varchar)

RETURNS integer AS '
declare
        p_program_id    alias for $1;   -- default null
        p_name          alias for $2;
        p_container_id  alias for $3;   -- default null
        p_group_id      alias for $4;
        p_start_date    alias for $5;   -- default now()
        p_end_date      alias for $6;   -- default null
        p_dc__description__abstract     alias for $7; --default null
        p_dc__description__long         alias for $8; --default null
        p_dc_description_long_format  alias for $9; --default null
        p_dc__type      alias for $10; --default null
        p_dc__language  alias for $11; --default null
        p_dc__coverage__spatial         alias for $12; --default null
        p_dc__coverage__temporal        alias for $13; --default null
        p_recurring_p   alias for $14;  -- default t
        p_context_id    alias for $15;  -- default null
        p_creation_user alias for $16;  -- default null
        p_creation_ip   alias for $17;  -- default null
        v_program_id    integer;
begin

        v_program_id := acs_object__new (
                p_program_id,
                ''radio_program'',
                now(),
                p_creation_user,
                p_creation_ip,
                p_context_id
        );

        insert into radio_programs 
          (program_id, name, container_id, start_date, end_date, dc__description__abstract, dc__description__long, dc_description_long_format, dc__type, dc__language, dc__coverage__spatial, dc__coverage__temporal, contributors_group_id, recurring_p) 
          values 
          (v_program_id, p_name, p_container_id, p_start_date, p_end_date, p_dc__description__abstract, p_dc__description__long, p_dc_description_long_format, p_dc__type, p_dc__language, p_dc__coverage__spatial, p_dc__coverage__temporal, p_group_id, p_recurring_p);

    return v_program_id;    
end;
' language 'plpgsql';


CREATE FUNCTION radio_program__delete(integer)
RETURNS integer AS '
declare
        p_program_id    alias for $1;
        v_group_id      integer;
        row             record;
begin        

        select contributors_group_id into v_group_id from radio_programs where program_id=p_program_id;

        
        for row in select object_id, privilege from acs_permissions where grantee_id=v_group_id loop
                perform acs_permission__revoke_permission(row.object_id, v_group_id, row.privilege);
        end loop;

        perform acs_group__delete(v_group_id);

        delete from radio_programs where program_id=p_program_id;

        perform acs_object__delete(p_program_id);

        return 0;
end;
' language 'plpgsql';

-- helper proc for radio-management that checks if radio_times 
-- possibly overlap
CREATE FUNCTION radio_nth_touch(integer,integer)
RETURNS boolean AS '
declare
        p_nth_1         alias for $1;
        p_nth_2         alias for $2;
begin
        if p_nth_1 = 0 or p_nth_2 = 0 then
                return ''t'';
        end if;

        if p_nth_1 = p_nth_2 then
                return ''t'';
        end if; 

        -- last in month conflicts with 4th in month.
        if p_nth_1 in (4, 6) and p_nth_2 in (4, 6) then
                return ''t'';
        end if;

        -- programs that are two-weekly clash with everything else that is not
        -- two-weekly
        if (p_nth_1=-2 and p_nth_2<>-2) or (p_nth_1<>-2 and p_nth_2=-2) then
                return ''t'';
        end if;

        return ''f'';
end;
' language 'plpgsql' with (iscachable);




CREATE FUNCTION inline_0 ()
RETURNS integer AS '
begin
    PERFORM acs_object_type__create_type (
        ''radio_emission'',     -- object_type
        ''Radio Emission'',     -- pretty_name
        ''Radio Emission'',     -- pretty_plural
        ''acs_object'',         -- supertype
        ''radio_emissions'',    -- table_name
        ''emission_id'',         -- id_column
        null,                   -- package_name
        ''f'',                  -- abstract_p
        null,                   -- type_extension_table
        null                    -- name_method
        );
    return 0;
end;' LANGUAGE 'plpgsql';

SELECT inline_0 (); 

DROP FUNCTION inline_0 ();

create table radio_emissions (
        emission_id int primary key references acs_objects(object_id) on delete cascade,

        -- reference to the next emission, null if last
        next_emission_id integer,
        program_id      integer not null references radio_programs,

        -- the exact start and end date and time
        start_date      timestamp not null,
        end_date        timestamp not null,

        -- reference to a preproduced file in an oma archive
        oma_url         varchar(1000),

        -- What the archiver process should do with this emission. null
        -- is interpreted as 'don't archive'. The meaning of other values depend
        -- on the customized installation. Option values are presented from the contents
        -- of the ArchiveDirectiveOptions parameter of radio-management.
        archive_directive       varchar(100),

        -- reference to the archived soundfile for this show
        archive_url     varchar(1000),

        internal_comments text,

        -- dublin core specific fields

        dc__title__alternative  varchar(255),
        dc__date__created       date,
        dc__date__digitized     date,
        dc__format__extent      varchar(1000),
        dc__format__medium      varchar(1000),
        dc__format__encoding    varchar(1000),
        
        -- sent from oma
        dc__identifier          varchar(1000),
        dc__publisher           varchar(1000),

        dc__source              varchar(1000),
        

        dc__rights              varchar(1000),
        dc__rights__license     varchar(1000),
        
        dc__description__toc    text,   
        dc_description_toc_format       varchar(100),
        dc__description__abstract       text,
        dc__description__long   text,

        -- e.g. text/plain or text/html
        dc_description_long_format varchar(100),
        
        dc__type                varchar(1000),
        dc__language            char(3),
        
        -- keywords
        dc__subject             varchar(1000),

        dc__coverage__spatial   varchar(1000),
        dc__coverage__temporal  varchar(1000),

        constraint chk_radio_emissions_date check (end_date > start_date)
);


create INDEX radio_emi_prg_id_idx on radio_emissions(program_id);

create INDEX radio_emi_dates_idx on radio_emissions(start_date, end_date);

create function radio_emission__new (integer,integer,timestamptz,timestamptz,integer,varchar)
RETURNS integer AS '
declare
        p_emission_id   alias for $1;   -- default null
        p_program_id    alias for $2;
        p_start_date    alias for $3;   -- default now()
        p_end_date      alias for $4;   -- default null
        p_creation_user alias for $5;  -- default null
        p_creation_ip   alias for $6;  -- default null
        v_emission_id    integer;
begin

        v_emission_id := acs_object__new (
                p_emission_id,
                ''radio_emission'',
                now(),
                p_creation_user,
                p_creation_ip,
                p_program_id
        );

        insert into radio_emissions (emission_id, program_id, start_date, end_date) values (v_emission_id, p_program_id, p_start_date, p_end_date);

        return v_emission_id;
end;' LANGUAGE 'plpgsql';



create function radio_emission__delete (
       -- 
       -- Deletes the emission and the associated event

       integer
)
returns integer as '
declare
       p_emission_id alias for $1; 
begin

        delete from radio_emissions where emission_id=p_emission_id;

        perform acs_object__delete(p_emission_id);
        
        return 0;
end;' language 'plpgsql'; 


-- **************************************************************************
-- Maintain radio_emissions_sorted that allows to query for gaps and overlaps

-- TODO: operations before the first or after the last emission
-- currently fail

create table radio_emissions_sorted (
        emission_id integer not null,
        next_emission_id integer not null,
        primary key (emission_id, next_emission_id)
);


-- this function rebuilds the whole table. to be called at
-- the beginning (?)
create function radio_emissions_build_sorted()
returns integer as '
declare
        row                     record;
        v_previous_emission_id  integer;
begin
        delete from radio_emissions_sorted;

        for row in select emission_id from radio_emissions order by start_date, emission_id loop

                if not v_previous_emission_id is null then
                        insert into radio_emissions_sorted (emission_id, next_emission_id) values (v_previous_emission_id, row.emission_id);
                end if;
                v_previous_emission_id := row.emission_id;
        end loop;
  

        return 0;

end;' language 'plpgsql';



-- ************************** delete *************************************

create function radio_emissions_sorted_del_fu(integer)
returns integer as '
declare
        p_old_emission_id       alias for $1;
        v_next_emission_id      integer;
begin
        select into v_next_emission_id next_emission_id from radio_emissions_sorted where emission_id=p_old_emission_id;

        if v_next_emission_id is null then
                -- the last emission was deleted
                delete from radio_emissions_sorted
                where next_emission_id=p_old_emission_id;
        else
                -- an emission somewhere in the middle was deleted
                -- (or maybe at the beginning but that is not considered)
                update radio_emissions_sorted set next_emission_id=v_next_emission_id
                where next_emission_id=p_old_emission_id;

                delete from radio_emissions_sorted 
                where emission_id=p_old_emission_id;
        end if;

        return 0;

end;' language 'plpgsql';




create function radio_emissions_sorted_del_tr() returns opaque as '
declare
        v_next_emission_id      integer;
begin

        perform radio_emissions_sorted_del_fu(old.emission_id);

        return old;
end;' language 'plpgsql';



create trigger radio_emissions_sorted_del_tr
after delete on radio_emissions
for each row execute procedure radio_emissions_sorted_del_tr();



-- **************************** insert ***********************************
create function radio_emissions_sorted_ins_fu(integer,timestamp)
returns integer as '
declare
        p_new_emission_id       alias for $1;
        p_new_start_date        alias for $2;
        v_next_emission_id      integer;
begin
        select into v_next_emission_id emission_id from radio_emissions
        where start_date >= p_new_start_date and emission_id != p_new_emission_id
        order by start_date limit 1;

        if v_next_emission_id is null then
                -- this was an insert after the last emission,
                -- so get an emission_id that has no pointer to the next emission.
                -- sorted in case there are more for some erroneous reason.
                select into v_next_emission_id e.emission_id from radio_emissions e
                left join radio_emissions_sorted s on e.emission_id=s.emission_id
                where s.emission_id is null and e.emission_id != p_new_emission_id
                order by e.start_date desc limit 1;

                -- if it is null again then this is the first insert at all
                if v_next_emission_id is null then
                        return 0;
                end if;

                insert into radio_emissions_sorted (emission_id, next_emission_id)
                values (v_next_emission_id, p_new_emission_id);
        else
                -- an insert somewhere in the middle or at the beginning 
                update radio_emissions_sorted set next_emission_id=p_new_emission_id
                where next_emission_id=v_next_emission_id;

                insert into radio_emissions_sorted (emission_id, next_emission_id)
                values (p_new_emission_id, v_next_emission_id);
        end if;

        return 0;
end;' language 'plpgsql';


create function radio_emissions_sorted_ins_tr() returns opaque as '
declare
        v_next_emission_id      integer;
begin

        perform radio_emissions_sorted_ins_fu(new.emission_id, new.start_date);

        return new;
end;' language 'plpgsql';


create trigger radio_emissions_sorted_ins_tr
after insert on radio_emissions
for each row execute procedure radio_emissions_sorted_ins_tr();



-- **************************** update **********************************
create function radio_emissions_sorted_upd_tr() returns opaque as '
begin

        perform radio_emissions_sorted_del_fu(old.emission_id);
        perform radio_emissions_sorted_ins_fu(new.emission_id,new.start_date);

        return new;

end;' language 'plpgsql';


create trigger radio_emissions_sorted_upd_tr
after update on radio_emissions
for each row execute procedure radio_emissions_sorted_upd_tr();






-- end of radio_emissions_sorted ----------------------------------------



-- Favourite programs - a simple mapping table

create sequence radio_favourite_id_seq;

create table radio_favourites (
        favourite_id    integer primary key default nextval('radio_favourite_id_seq'),
        user_id integer not null references users(user_id) on delete cascade,
        program_id integer not null references radio_programs(program_id) on delete cascade
        
        -- just an idea ...
        --mail_p boolean,
        --mail_before interval
);



-- track signed contracts. every contract in here is assumed to be signed - 
-- unsigned contracts won't be entered here.

create sequence radio_contract_id_seq;

create table radio_contracts (
        contract_id     integer primary key default nextval('radio_contract_id_seq'),
        program_id      integer not null references radio_programs(program_id),
        start_date      date not null,
        end_date        date not null,
        signed_p        boolean not null default('f'),
        -- the radio maker user_id that signed the contract
        signer_id       integer references persons(person_id),

        -- the staff user that entered this contract as signed
        creation_user_id   integer references users(user_id),
        creation_date   date default now()

);


create function radio_date_within() returns boolean as '
begin

        perform radio_emissions_sorted_del_fu(old.emission_id);
        perform radio_emissions_sorted_ins_fu(new.emission_id,new.start_date);

        return new;

end;' language 'plpgsql';


