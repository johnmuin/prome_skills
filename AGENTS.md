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
6. When developing bioinformatics workflows, define standardized data interfaces before implementation. This includes input file naming, sample identity rules, required paired files, reference database requirements, read length assumptions, output directory layout, and key output file contracts.
7. Standardized data interfaces should have an explicit pre-run confirmation step. For interactive work, ask the user to confirm paths and interface assumptions before heavy compute; for scripts, encode the same checks in `preflight.sh` with clear [PASS]/[WARN]/[FAIL] messages.
8. Runtime environments should be managed through a dedicated runtime/environments directory instead of being scattered across flow configs and docs. The structure should support conda/mamba environment files, Apptainer definitions, Dockerfiles, runtime checks, and ignored server-specific profiles. Flow project configs should focus on project data interfaces, while runtime profiles describe how to locate tools, references, and execution backends on a server.

## Reference-Specific Runtime Notes

1. Kraken2 flow runs need a Kraken2 database containing `hash.k2d`, `taxo.k2d`, `opts.k2d`, and `database*<N>mers.kmer_distrib`. The Kraken2 and Bracken versions must match the database build.
2. Kraken2 flow runs need KrakenTools (`jenniferlu717/KrakenTools`). The checkout must contain `kreport2mpa.py` and `combine_mpa.py`.
3. Server-specific paths belong in `runtime/environments/profiles/<server>.sh`. Create one per server and source it before creating a project config. The committed `runtime/environments/profiles/template.sh` documents the expected variables.
4. Always run `preflight.sh` before starting heavy compute. See `docs/troubleshooting.md` for common failure patterns and diagnostic commands.
