
# Kraken Analytics - current-state assesment and migration plan.




## Executive summary
>
>
>
>
>
>

## Current-state assessment & prioritisation.

The problems you found, each with a severity
   and a one-line *business* impact. Prioritised — don't just list everything
   flat. We want to see what you'd touch first and what you'd consciously leave
   alone for now.

The current state of kraken analytics is a combination of a organisational issues and analytics engineering/best-practice issues. When planning the migration, the priority should be on restoring main reporting for the business, while not compromising on the reliability of the data and thefuture-state design. Therefore the proposed order of problems to address is:

1. _Severity: Critical_ **The business does not have a reliable source of truth.** Currently, there are three dbt models cited as a source of truth for the daily count of raids definitions (raids_fact, daily_active_captains, or fct_raids). The first thing to address is confirming the **official** business definition of the daily raids count and working on getting the correct numbers into exec dashboard. 


2. _Severity: Critical_ **Uniquness test on the main source table is failing, leading to potential reporting inconsitencies and compromising the reliability/trust.** Ideally, duplication issues should be solved at the source. If not possible, deduplication needs to happen in the staging layer (first layer from raw data), with clear documentation on context of these duplicates, so that we are not accidentally masking deeper issues in data production. This deduplication is already happening in `stg_raids` but also needs more explanation on how the correct row is being chosen. 

3. _Severity: Critical_ **Main business dashboard relies on a model marked as 'experimental' and with no clear ownership.** 
Despite being marked as 'experimental', model 'churn_score_v3`feeds into the main executive "Captain Health" dashboard. The owner of the model has since left the business and it is not clear whether they left any documentation explaining the logic. Additionally, this model has  has hardcoded dates, which suggests that the scores might be silently degrading. 

4. There is PII exposed in business dashboards. Column `parley_address` should be immediately removed from all layers, from staging to reporting (potenially even from raw). When there is a documented business case for exposure of PII (e.g. an HR report), this can be addressed accordingly. 

7. Main business dashboard relies on a table outside of dbt, written by a cron Python script with no team ownership. Only two columns are used: last_raid_utc and sanctioned_plunders, which could be both easily defined using the source table `raw.raids`. 


4. Raw data is kept in UTC but the reporting is expected to be in Port Royale (`America/Jamaica`, UTC-5) time. Models in the repository contain a mix of timestamp/date fields in both timezones, but it's not clearly stated in the column names.

4. Staging layer is doing too much (and inconsistently). 

`stg_raids` joins to `stg_captains`, deduplicates, derives business flags, and converts timezones — all in a staging model. The other staging models (`stg_captains`, `stg_ships`, `stg_plunder_sales`) are simple pass-throughs. Staging should be a uniform, light cleaning layer: rename columns, cast types, apply source filters, (maybe) deduplicate. Business logic belongs in later layers. 

5. Models from layers 'above' the staging read directly from raw sources. Examples: `int_raids_enriched`, `analytics.raids_fact`

6. `fct_raids` overrides its own materialisation

`dbt_project.yml` sets `gold: +materialized: table`. `fct_raids.sql` overrides this with `{{ config(materialized='view') }}`. This is the "source of truth for raids" and the model that powers downstream marts — it should probably be a table for query performance and reliability, not a view. If there is a reason for this to be a view - it needs documenting.




8. Inconsistent columns naming. `raids_fact`. Renames `captain_id` to `buccaneer_id` with no documentation. If we consider 'analytics' folder to be responsibility of the growth team, we can deam this as a lesser priority to fix ourselves, however, the official business lexicon & naming conventions should be shared with the business and everyone is _expected_ to follow.


No source freshness testing.

No sql style guide

   

## Target-state design.
 The layered architecture you'd steer toward — naming,
   schema/layer responsibilities, a single source of truth for the contested
   metrics, ownership, testing/governance. A diagram (even ASCII or Mermaid) is
   welcome. Be opinionated.

##  Migration plan.
How you get from here to there *without* a big-bang
   rewrite. Sequencing, how you retire the duplicate "gold" layers without
   breaking the dashboards that read them, what you'd put in place to stop this
   recurring.


## Open questions



## 

### One worked example (optional but encouraged).

** Pick one slice and show the
   standard you'd hold the team to — e.g. a single conformed raid fact that
   resolves the "how many sanctioned raids in May" disagreement, with tests. A
   real `.sql` model in the project, or just the code in your write-up. You do
   **not** need to refactor everything; one well-chosen example says more than
   ten rushed ones.

### What you'd do with more time, and the open questions** you'd take to Morgan.

There's no single right answer. We're evaluating judgement, prioritisation, and
the quality of your reasoning — not how many files you changed.