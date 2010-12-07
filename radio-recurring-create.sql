-- This datamodel deals with recurrency schemes which are applicable
-- to all objects that recur within regular intervals. The actual
-- manifestations of the recurrence will be stored with the object
-- data itself, not here.



create sequence radio_recurring_ranges_seq;


-- define a date range within which a group of recurring entries is valid.
-- this is used for containers, to allow for creating multiple sets
-- of times that represent different program plans. radio_programs do not 
-- have this capability for storing their recurring history as of now.

-- actually it should be called radio_container_ranges or sth like that.

-- only one container range should be active at a time - not sure if that's
-- enforcable though.

create table radio_recurring_ranges (
    range_id    integer not null primary key default nextval('radio_recurring_ranges_seq'),

    -- an optional name to identify this range. (e.g. 'Summer 2004 Schedule')
    name        varchar(100),

	-- Date range within which this range is valid.

    -- when start_date is null, the range is not active yet, e.g.
    -- for drafts.
    start_date  date,

    -- when end_date is null it means it has an open end.
    end_date    date
    
);

-- helper table that only holds one row with one value: up to which
-- date the db has been filled with pregenerated instances.
create table radio_containers_populated (
    containers_populated_until  date
);
insert into radio_containers_populated (containers_populated_until) values (null);


-- Insert one default range.
insert into radio_recurring_ranges (name) values ('Default Range');

create sequence radio_recurring_times_seq;

-- each row of radio_recurring_times represents one recurrance,
-- e.g. 'every 1st friday'.

create table radio_recurring_times (
    recurring_time_id         integer not null primary key default nextval('radio_recurring_times_seq'),

    -- used to group schemas for containers. irrelevant (null) for 
    -- programs.
	range_id 	integer references radio_recurring_ranges(range_id) on delete cascade,

    -- refers to the actual object, e.g. a program or a container
    object_id   integer not null references acs_objects(object_id) on delete cascade,

    start_time      time    not null,

	-- Length of recurrance. Must be an interval that is understood
	-- both by postgresql and tcl, e.g. '1 day'. Storing amounts of 
	-- seconds is not possible for longer durations because of daylight
	-- savings.
	duration	interval not null
	constraint radio_recurring_time_duration_positive check(duration > 0),
 
    -- the weekday number (-1=every day, 0=sunday, 1=monday ...)
    weekday         integer not null,

    -- Contains the monthly occurence where 0=every week, 
    -- 1=first weekday in month, 2=second ...
    -- special cases: -2=every 2 weeks, 6=every last
    nth_in_month    integer not null default 0,

    -- An example date when the two-weekly recurs, to 
    -- adjust the recurrence accordingly. Must be on the same
	-- weekday.
    two_week_start  date
	
);

