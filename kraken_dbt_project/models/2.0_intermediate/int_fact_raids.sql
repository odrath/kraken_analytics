with raids AS (
    SELECT
        raid_id
        ,captain_id
        ,rival_captain_id
        ,raid_ship_id
        ,started_at_utc
        ,(started_at_utc at time zone 'UTC' at time zone 'America/Jamaica') as started_at_ame_jam
        ,raid_status
        ,is_sanctioned,
        ,victor_captain_id
FROM { ref('kraken_logbook__fact_raids') }}
)

SELECT *
FROM raids