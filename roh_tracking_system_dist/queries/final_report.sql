WITH latest_roh AS (

    SELECT
        wagon_no,
        work_center_id,
        wagon_stage_id,
        booked_to,
        unfit_memo_date,
        last_updated_date,

        (CURRENT_DATE - unfit_memo_date::date) AS overdue_days,

        ROW_NUMBER() OVER (
            PARTITION BY wagon_no
            ORDER BY last_updated_date::timestamp DESC NULLS LAST
        ) rn

    FROM lb1adm.fmm_wagon_stage_t

    WHERE maintenance_type = 'ROH'
),

active_roh AS (

    SELECT *

    FROM latest_roh

    WHERE rn = 1

    AND wagon_stage_id IN (
        'YARD_UNFIT',
        'UNFIT',
        'CALL_MEMO',
        'NTXR_UNFIT'
    )

    AND overdue_days <= 100
),

latest_rake AS (

    SELECT
        wagon_no,
        rake_id,
        wagon_status,
        wagon_status_dt,
        updated_on,

        ROW_NUMBER() OVER (
            PARTITION BY wagon_no
            ORDER BY
                wagon_status_dt::timestamp DESC NULLS LAST,
                updated_on::timestamp DESC NULLS LAST
        ) rn

    FROM lb1adm.roams_rake_details

    WHERE wagon_status IN (
        'DISPATCHED',
        'DETACHED'
    )
),

current_rake AS (

    SELECT *

    FROM latest_rake

    WHERE rn = 1
),

base_data AS (

    SELECT

        r.work_center_id AS roh_depot,
        c.rake_id,
        r.wagon_no,
        r.overdue_days,
        r.booked_to,

        f.ravsttn,
        f.ravsttnto,
        f.radarvltime

    FROM active_roh r

    JOIN current_rake c
        ON r.wagon_no = c.wagon_no

    JOIN data_analysis.mat_view_wagon_last_arrival_as_per_fois f
        ON r.wagon_no = f.ravwgonnumb
       AND f.radarvltime IS NOT NULL
)

SELECT

    roh_depot AS "ROH Depot",

    rake_id AS "Rake ID",

    COUNT(DISTINCT wagon_no) AS "Number of Wagons",

    MAX(overdue_days) AS "Overdue Days",

    MAX(ravsttn) AS "Current Station",

    MAX(ravsttnto) AS "Next Station",

    MAX(booked_to) AS "Destination",

    MAX(radarvltime) AS "Last Updated"

FROM base_data

GROUP BY
    roh_depot,
    rake_id

ORDER BY
    roh_depot,
    COUNT(DISTINCT wagon_no) DESC,
    MAX(overdue_days) DESC,
    MAX(radarvltime) DESC NULLS LAST;