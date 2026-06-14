
# Kraken Analytics - current-state assesment and migration plan.




## Executive summary
> The current state of kraken analytics is a combination of a organisational issues and analytics engineering/best-practice issues. When planning the migration, the priority should be on restoring main reporting for the business, while not compromising on the reliability of the data.
> Therefore, in first steps, we will start with a thin slice of a clean dbt project, that will feed a few main business metrics that the War Council is currently relying on (MVP). We will build them using the new modelling architecture, which follows best practice and ensures data reliability. Once the MVP stage is completed, we will briefly focus on establishing future-proof analytics engineeering workflows. After that, we will continue building further models, based on the business pririotisation. 
> 
>
>
>

## Current-state assessment & prioritisation.


The proposed order of problems to address is:

1. _Priority: High_ **The business does not have a reliable source of truth.** 
  1. Currently, there are three dbt models cited as a source of truth for the daily count of raids definitions (raids_fact, daily_active_captains, or fct_raids). The **official** business definition of the daily raids count needs to be confirmed, consolidating models and working on getting the correct numbers into exec dashboard. 

  2. Two revenue models with different logic: `fct_plunder_sales` and `fct_plunder_sales_old.sql`. The best course of action would be to confirm with finance which model whether the old model is still needed. If it's not, deprecate and delete it. If it's needed for historical audit purposes - rename, clearly document and move to a finance data mart.

  3. `captain_360` and `dim_captain` are near-duplicates with different lineage and should be consolidated. Growth team should not be creating any additional sources of truth but build on top of the core data assets in the the gold layer.


2. _Priority: High_ **Uniquness test on the main source table is failing, leading to potential reporting inconsitencies and compromising the reliability/trust.** 
Ideally, duplication issues should be solved at the source. If the log entry is editable, it should result in the row being updated with a timestamp `updated_at`. 
If absolutely not possible, deduplication needs to happen in the first layer after raw data (staging), with clear documentation on context of these duplicates, so that we are not accidentally masking deeper issues inherited from data producers. This is already happening in `stg_raids` but also needs more explanation on how the correct row is being chosen. We should be able to use `created_at`.

3. _Priority: High_  **Main business dashboard relies on a table outside of dbt, written by a cron Python script with no team ownership.**
Upon a closer look, only two columns are used: `last_raid_utc` and `sanctioned_plunders`, which, based on my investigation, could be both easily defined using the source table `raw.raids`. If my analysis gets confirmed, this legacy Python script can be retired.

4. _Priority: High_ **Main business dashboard relies on a model marked as 'experimental' and with no clear ownership.** 
Despite being marked as 'experimental', model `churn_score_v3` feeds into the main executive "Captain Health" dashboard. The owner of the model has since left the business and it is not clear whether they had written any documentation explaining the logic. Additionally, this model has  has hardcoded dates, which suggests that the scores might be silently degrading. Until we can confirm the reliability of the values in `desertion_probability` column, this field should be removed from reporting. A seperate project to update the churn scoring model might to be scoped to be delivered after main issues have been addressed. (If we can hand-over to the data science team and they have capacity, this could be delivered concurrently.)

4. _Priority: High_ **There is PII unnecessarily exposed in business dashboards, creeating data privacy/legal risks.**
Column `parley_address` should be immediately removed from all layers, from staging to reporting (potenially even from raw). Further down the line, if/when there is a documented business case for any exposure of PII in a controlled way (e.g. an HR report with limited access), this can be addressed accordingly.


5.  _Priority: Medium-High_ **A manual SQL script outside of dbt's DAG.**

View `manual.ship_overrides` is created by running a raw SQL file manually. The values are hand-keyed integers with comments. This means:
- There are no dbt tests on this data.
- Changes are not captured in version control via dbt.
- There's no freshness signal.

 The current size of the table (4 rows) is trivially small. At minimum, we should convert `manual.ship_overrides` to a dbt seed (`seeds/ship_overrides.csv`) and establish a clear ownership of the file. Seeds are versioned, diff-able, and can have schema tests applied. Remove `manual_views/create_views.sql` once migrated. If there is a way to pull this data from an external system, this would be preferable over a seed.

6.  _Priority: Medium-High_ **There is an SCD2 on static data.**

Comments in the `class_snapshot` say : "ship classes have not changed in centuries." SCD2 snapshots on immutable reference data impose a `dbt_valid_to is null` filter burden on every consumer, increase storage, and add complexity for no benefit. The snapshot's own docstring identifies this as a problem. `int_raids_enriched` currently reads from `class_snapshot`, however there is no filter applied on `dbt_valid_to`, potentially because there is no actual duplication. Upon closer look, this snapshot only brings a `class_id` into the intermidiate layer, which is not a field needed in the dashbord. We can safely turn off the snapshot runs and remove the CTE from `int_raids_enriched`. In the later steps, we can replace `class_snapshot` with a simple `ref('stg_ship_classes')` staging model. Remove the snapshot. Audit any other potential consumers for the now-unnecessary `dbt_valid_to is null` filter, if in use. 

7. _Priority: Medium_ **Timezones mismatch and lack of documentation.**
Raw data is kept in UTC but the reporting is expected to be in Port Royale (`America/Jamaica`, UTC-5) time. Models in the repository contain a mix of timestamp/date fields in both timezones, but it's not clearly stated in the column names. There should be a rule where non-UTC timestamps should have a relevant suffix, e.g. `raided_at_ame_jam`.

8. _Priority: Medium_ **Staging layer is doing too much (and inconsistently).**

`stg_raids` joins to `stg_captains`, deduplicates, derives business flags, and converts timezones — all in a staging model. The other staging models (`stg_captains`, `stg_ships`, `stg_plunder_sales`) are simple pass-throughs. Staging should be a uniform, light cleaning layer: rename columns, cast types, apply source filters, (maybe) deduplicate. Business logic belongs in later layers. 

9.  _Priority: Medium_ **Models from layers 'above' the staging read directly from raw sources.**

Examples: `int_raids_enriched`, `analytics.raids_fact`, `fct_plunder_sales_old.sql`

10. _Priority: Medium_ **`fct_raids` overrides its own materialisation**

`dbt_project.yml` sets `gold: +materialized: table`. `fct_raids.sql` overrides this with `{{ config(materialized='view') }}`. This is the "source of truth for raids" and the model that powers downstream marts — it should probably be a table for query performance and reliability, not a view. If there is a reason for this to be a view - it needs documenting.


11. _Priority: Medium_ **Tests are disabled or missing.**
At minimum, not_null and unique tests should be implemented in all models. For large tables, these should be limited to the timeframe since last test run. Strategy of using unit testing for more complex business logic, should be established. 

12. _Priority: Medium_ **No source freshness testing.**

13. _Priority: Medium_ **No documentation - missing models and columns description.**  

14. _Priority: Low_ **No tags.**  
There should be a system of what different tags represent:
- cadence (hourly, daily, weekly, static)
- team ownership (growth, product, finance)

15. _Priority: Low_ **No sql style guide. No linting.**

15. _Priority: Low_ **No documented dbt-developer flow. No pre-commit hooks enforcing the rules.**

16. _Priority: Low_ **No defined exposures.**

16. _Priority: Low_ **Inconsistent columns naming.**

`raids_fact`. Renames `captain_id` to `buccaneer_id` with no documentation. If we consider 'analytics' folder to be responsibility of the growth team, in the 'data mesh' spirit, we can deam this as a lesser priority to fix ourselves, however, the official business lexicon & naming conventions should be shared with the business and everyone is _expected_ to follow.



 
   

## Target-state design.
 The layered architecture you'd steer toward — naming,
   schema/layer responsibilities, a single source of truth for the contested
   metrics, ownership, testing/governance. A diagram (even ASCII or Mermaid) is
   welcome. Be opinionated.


This is a proposed modelling architecture, which may change depending on the deeper analysis of the business needs. 

### Layers (diagram in dbt_modelling_layers_dependency.png):
0.0. Sources - data in source tables synced directly into `raw` schema in the data warehouse
0.1. MANUAL - data from seeds 
0.2. UTILITIES - SQL-generated helper tables, such as dim_calendar and dim_calendar_hh, for easy timezone coversion of timestamps in BI tools. 
1.0. STAGING - rename columns, cast types, apply source filters
Naming convention is `(source_name)__dim_(model_name)` or `(source_name)__fact_(model_name)` 
2.0 INTERMEDIATE (silver) - some business logic applied here, intermidiate models built for modularity and ease of debugging. Not exposed in the BI tool. 
Naming convention `int_(dim/fact/agg)_(model name)`. 
3.0 BI (gold) - core data assets exposed in the BI tool. Teams also use this layer to build their own data marts on top. 
Naming convention `(dim/fact/agg)_(model name)`. 
4.0 <if needed > BI_ROLLING - models with rolling window calculations for business users self-service in Metabase. All model names start with `agg_`.
5.0. Team specific data marts, e.g. GROWTH_ANALYTICS, FINANCE_ANALYTICS etc

There is also an official metrics layer (e.g. Snowflake Semantic View, dbt Semantic Layer, Metric in Metabase). 

SQL Style guide written and shared with all dbt developers. I usually base mine off [this Gitlab one] (https://handbook.gitlab.com/handbook/enterprise-data/platform/sql-style-guide/).  SQL linting package added to the project to enforce most of them (trailing vs leading commas, spacing,indentetion, capitalisation etc etc). 

dbt workflow guide written and shared with all dbt developers. dbt pre-commit hooks implemented to enforce things like no hardcoded table paths, tests added to every model, columns documented etc 


### Ownership:
Staging, intermediate and gold layers belong to central data team. The same applies to core business metrics derived from them. 

Schema and metrics in the data mart layer, belong to business-embedded analysts (growth, finance, product etc).

##  Migration plan.
1. Start with a thin slice of models following the target architecture and leading to the metrics: daily_active_captains, daily_raids, daily_santioned_raids.  Define and document the business definition somewhere where everyone has access. Include full logic: timezone, aggregations/how the metric is sliced (e.g. per geo region), is there any window function applied etc
2. Build staging/intermediate/bi models leading to the fact_raids table. 
3. Build 3 prioritised metrics, these will be conttrolled by the central data-team.
4. Implement good practice rules for the future, which will ensure consistency in code and reliability of data:
  - SQL linter
  - pre-commit hooks
  - documentation rules (e.g. all BI models need every column description)
5. Continue building for the future. 


## Open questions

Are there created_at and updated_at fields in raw tables?Are there any sources worth snapshotting?
Are there any models worth being incremental?
Do we need any rolling windows models to mitigate seasonality?  Metabase's GUI currently cannot calculate window functions outside of a cumulative sum/count.
