# Project Agent Instructions

## Development And Testing Conventions

1. All full test runs should be performed on the `pg-xujm` server over SSH.
2. Test environments on `pg-xujm` should be deployed through newly created conda environments.
3. The project can be cloned on `pg-xujm` under `/share/data2/xujm/apps`.
4. Test case code for this project can be tracked in git so tests remain traceable.
5. The normal development loop is:
   - modify code locally;
   - run simple lightweight local tests;
   - commit changes with git;
   - pull the committed code on `pg-xujm`;
   - run production-grade data tests on `pg-xujm`;
   - if test feedback shows issues, return to local development and iterate;
   - repeat until production-grade tests pass.
6. Repository scripts, templates, and committed documentation should stay portable and avoid server-specific names, private absolute paths, or local-only operational details. Keep those details in local memory, local runtime config files, or ignored project notes instead.

## Reference-Specific Runtime Notes

1. The GVMG Kraken database at `/share/pynas0/pub_data/GVMG/data/work/krakendb_202408` should be used with Kraken2 v2.1.2 and Bracken v2.7.
2. Kraken2 flow runs need KrakenTools (`jenniferlu717/KrakenTools`). On `pg-xujm`, use `export KRAKEN_TOOLS_DIR="/share/data2/xujm/apps/MAG_flow/utils/KrakenTools-master"`, which should contain `kreport2mpa.py` and `combine_mpa.py`.
3. Server-specific paths are centralized in `env_profiles/pg-xujm.sh`. Source this before creating a project config.
4. Always run `preflight.sh` before starting heavy compute. See `docs/troubleshooting.md` for common failure patterns and diagnostic commands.
