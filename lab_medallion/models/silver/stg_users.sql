with source as (
    select * from {{ source('bronze', 'users') }}
),

first_orders as (
    select user_id, min(ordered_at) as first_order_at
    from {{ ref('stg_orders') }}
    group by user_id
),

typed as (
    select
        cast(s.uuid as uuid) as user_id,
        trim(s.username) as username,
        lower(trim(s.username)) as username_normalized,
        trim(s.name) as name,
        upper(trim(s.sex)) as sex,
        lower(trim(s.mail)) as email,
        cast(s.birthdate as date) as raw_birthdate,
        f.first_order_at,
        split_part(s.address, chr(10), 1) as street,
        split_part(s.address, chr(10), 2) as address_line_2
    from source s
    left join first_orders f on cast(s.uuid as uuid) = f.user_id
)

select
    user_id,
    username,
    username_normalized,
    name,
    sex,
    email,
    case when first_order_at is null or raw_birthdate <= first_order_at
         then raw_birthdate end as birthdate,
    coalesce(first_order_at is null or raw_birthdate <= first_order_at, false) as birthdate_is_valid,
    street,
    nullif(regexp_extract(address_line_2, '^(.+), [A-Z]{2} \d{5}$', 1), '') as city,
    regexp_extract(address_line_2, '([A-Z]{2}) (\d{5})$', 1) as state,
    regexp_extract(address_line_2, '([A-Z]{2}) (\d{5})$', 2) as zip_code
from typed
