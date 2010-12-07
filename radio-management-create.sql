

-- a helper table to store special groups used throughout the
-- package. should only contain one row.
create table radio_magic_group_ids (
        editors_group_id        integer not null,
        contributors_group_id   integer not null
);

create table radio_persons (
        person_id integer primary key references persons(person_id),

        phone           varchar(255),
        location        varchar(255),
        internal_comments       text
);

-- create the two magic groups and insert them into
-- radio_magic_group_ids
CREATE FUNCTION inline_0 ()
RETURNS integer AS '
declare
    v_editors   integer;
    v_contributors   integer;
    v_bogus     integer;
begin
    v_editors := acs_group__new(''Editors'');
    v_contributors := acs_group__new(''Contributors'');

    insert into radio_magic_group_ids (editors_group_id, contributors_group_id) values (v_editors, v_contributors);
 
    -- Also create these two ''magic'' groups, which are referenced
    -- by name from the admin interface. Not sure if they make sense
    -- for the generic code besides for reboot.fm, hmm.

    v_bogus := acs_group__new(''Techies'');
    v_bogus := acs_group__new(''Syndicators'');


    return 0;
end;' LANGUAGE 'plpgsql';

SELECT inline_0 (); 

DROP FUNCTION inline_0 ();



\i radio-recurring-create.sql
\i radio-containers-create.sql
\i radio-programs-create.sql


-- Deactivated for now. Run it manually if you want search (and install the search
-- package first).
-- \i radio-search-create.sql


-- needed only if that function didn't make it into openacs yet
\i update-last-modified-non-recursive.sql
