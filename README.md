## This repository contains:

* `writeup.md` - document for Morgan to take to the War Council. It starts with an executive summary, followed by detailed list of the issues to address, in order of priority. It also has a future state architecure and a high-level execution plan.

* `dbt_modelling_layers_dependecy.png` - diagram of dbt modelling leayers

* `kraken_dbt_project` - a starter dbt project with a worked example of a thin slice (raids count metric). It assumes duplication problems have been solved at the source and that our BI tool can read from dbt Semantic Layer (Metabase actually does not have an official connector). It also assumes that aggregating data-on-the-fly is not costly. However, in the target modelling architecture, I suggest creating aggregated models and also a seperate layer for rolling-window type of aggregated tables. My point is that the path we chose, ultimately, depends on the business needs and other tools' limitations. 



## Notes on the AI usage

I used Claude in the initial stage of the task. I asked it to read the dbt project, as well as the `DATA_DICTIONARY.md` and audit it based on the analytics engineering best practice and business perspective. It was able to identify several issues, where the project did not align with the dbt documentation best practice. However:
- despite reading the data dictionary, LLMs understanding of business perspective was quite poor
- the prioritisation was off, it would exaggerate issues, which were cosmetic and did not have an immediate impact on the ability to deliver reliable business metrics
- some recommendation were inadequate and lacked the true understanding of what was significant and what relationships/columns were redundant
    - One example was when it suggested making the cron Python script a source. It would not solve the issue of having business logic completely outside of the version-controlled dbt project. Upon reading sql files, I was able to deduct that the script could be probably retired altogether and replaced fully by transforming logbook data inside the dbt project. 
- AI suggestions what to add to the project, did not go beyond the very basics (tests on primary keys, source freshness). It did not suggest anything about more sophisticated testing, exposures, semantic layer, dbt-docs enrichment etc

Overall - it was a handy way to speed up the process of reading through the files and get a list of things to dig deeper into but it did not replace the actual analysis of an experienced analytics engineer. I ended up reading through all the files multiple time myself to confirm AI-s assessment and there were a lot of its suggestions that I had to re-prioritise or even discard.

Once the initial planning is completed and the project template is established, there will be some repetitive tasks to automate.