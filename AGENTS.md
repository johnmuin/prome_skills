# Project Agent Instructions

## Development And Testing Conventions

1. All full test runs should be performed on the designated test server over SSH.
2. Test environments on the test server should be deployed through newly created conda environments.
3. Test case code for this project can be tracked in git so tests remain traceable.
4. The normal development loop is:
   - modify code locally;
   - run simple lightweight local tests;
   - commit changes with git;
   - pull the committed code on the test server;
   - run production-grade data tests on the test server;
   - if test feedback shows issues, return to local development and iterate;
   - repeat until production-grade tests pass.
5. Repository scripts, templates, and committed documentation should stay portable and avoid server-specific names, private absolute paths, or local-only operational details. Keep those details in local memory, local runtime config files, or ignored project notes instead.

## Reference-Specific Runtime Notes

1. Kraken2 flow runs need a Kraken2 database containing `hash.k2d`, `taxo.k2d`, `opts.k2d`, and `database*<N>mers.kmer_distrib`. The Kraken2 and Bracken versions must match the database build.
2. Kraken2 flow runs need KrakenTools (`jenniferlu717/KrakenTools`). The checkout must contain `kreport2mpa.py` and `combine_mpa.py`.
3. Server-specific paths belong in `env_profiles/<server>.sh`. Create one per server and source it before creating a project config. The committed `env_profiles/template.sh` documents the expected variables.
4. Always run `preflight.sh` before starting heavy compute. See `docs/troubleshooting.md` for common failure patterns and diagnostic commands.
