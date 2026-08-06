# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

This repo has two parts:
- Root: a minimal `uv`-managed Python project (`main.py`, `pyproject.toml`) that only pins the Python/dbt dependencies (`dbt-core==1.11.11`, `dbt-snowflake==1.11.6`, Python `>=3.13`). It is not the application logic.
- `dbt_demo_project/`: the actual dbt project (profile name `dbt_demo_project`), targeting Snowflake. All model/macro/source work happens here.

## Commands

Run dbt commands from `dbt_demo_project/` (it contains `dbt_project.yml`).

```bash
# install deps (uv-managed)
uv sync

# core dbt workflow
dbt run                 # build models
dbt test                # run tests
dbt build                # run + test in DAG order (used in CI/CD)
dbt run --select <model>  # build a single model, e.g. dbt run --select dim_clients
dbt test --select <model> # test a single model
```

dbt needs a `profiles.yml` with a `dbt_demo_project` profile and Snowflake credentials to run locally; it is not committed to the repo (keep credentials out of git — do not create/commit one with real secrets).

There is no separate lint/format tooling configured in this repo (no `.sqlfluff`, no linter deps in `pyproject.toml`).

## Architecture

### Medallion layering (bronze / silver / gold)

Models are organized under `models/` by medallion layer, and `dbt_project.yml` assigns per-layer database/schema/materialization config:

- **bronze**: not dbt models — declared as a `source` in `models/bronze/source.yml` (source name `bronze`, e.g. `raw_clients`). Points at externally-loaded raw tables in the `{DEV|PROD}_BRONZE.GED` schema.
- **silver** (`models/silver/<subfolder>/`, e.g. `GED/`): staging models built directly on bronze sources (e.g. `stg_clients_23.sql` selects from `source('bronze', 'raw_clients')`). Materialized `incremental` by default, database `{DEV|PROD}_SILVER`, schema per subfolder (e.g. `GED`).
- **gold** (`models/gold/<subfolder>/`, e.g. `dim/`): consumer-facing models built on silver via `ref()` (e.g. `dim_clients.sql` selects from `ref('stg_clients_23')`). Materialized as `table`, database `{DEV|PROD}_GOLD`, schema per subfolder (e.g. `REF` for dimension models).

When adding a model, put it in the matching layer folder — config (database/schema/materialization) is inherited from `dbt_project.yml` by folder path, not set per-model.

### Environment-aware database naming

Database names are computed inline with `{{ 'DEV' if target.name == 'dev' else 'PROD' }}_<LAYER>` in both `dbt_project.yml` and `source.yml`. This pattern must be replicated anywhere a fully-qualified database name is referenced, so a single dbt project can target either `DEV_*` or `PROD_*` Snowflake databases depending on the active target.

Schema naming is overridden by `macros/generate_schema_name.sql`: unlike dbt's default (which prefixes custom schemas with the target schema), this macro uses the model's `custom_schema_name` verbatim when set, and falls back to `target.schema` otherwise. Keep this in mind when setting `+schema` in `dbt_project.yml` or model configs — there is no `<target_schema>_<custom_schema>` concatenation here.

### CI/CD deployment model (Snowflake-native, not dbt Cloud/local runner)

CI/CD (`.github/workflows/dbt_ci.yml`, `dbt_cd.yml`) does not run `dbt` directly on the GitHub runner. Instead it uses the Snowflake CLI (`snow sql`) to drive Snowflake's native **DBT PROJECT** object against a Snowflake **git repository integration**:

1. `ALTER GIT REPOSITORY ... FETCH` — syncs Snowflake's view of the repo.
2. `CREATE OR REPLACE DBT PROJECT ... FROM '@.../branches/<branch>/dbt_demo_project' DEFAULT_TARGET = '<target>'` — (re)creates the Snowflake DBT PROJECT object from the branch contents.
3. `EXECUTE DBT PROJECT ... ARGS = 'build --target <target>'` — runs `dbt build` inside Snowflake.

- CI (`dbt_ci.yml`): triggers on PRs into `dev` or `main`; uses the `dev` connection/target, role `SVC_DBT_DEV_ROLE`, warehouse `DEV_TRANSFORM_WH`, and reads the `dev` branch.
- CD (`dbt_cd.yml`): triggers on push to `main`; uses the `prod` connection/target, role `SVC_DBT_PROD_ROLE`, warehouse `PROD_TRANSFORM_WH`, and reads the `main` branch.
- Auth is via Snowflake key-pair JWT (`SNOWFLAKE_PRIVATE_KEY`, `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`, `SNOWFLAKE_ACCOUNT` secrets), not username/password.

Implication: local `profiles.yml` targets (`dev`/`prod`) should stay consistent with the `target.name` checks used throughout the models/macros, since both local dbt runs and the Snowflake-native CI/CD path rely on the same `target.name`-driven database naming.
