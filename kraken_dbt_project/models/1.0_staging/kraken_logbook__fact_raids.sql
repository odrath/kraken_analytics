

with raids AS (
    SELECT
        raid_id
        ,captain_id
        ,rival_captain_id
        ,raid_ship_id
        ,started_at_utc
        ,status AS raid_status
        ,is_sanctioned,
        ,victor_captain_id
FROM {{ source('raw', 'raids') }}
)

SELECT *
FROM raids





