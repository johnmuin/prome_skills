# prome_skills

Lightweight bioinformatics flows that remain easy for humans to run and structured enough for LLM agents to use safely.

This repository collects PROME-style analysis flows, environment conventions, and Codex/OpenAI skill wrappers.

## Layout

```text
prome_skills/
├── flows/                 # Runnable command-line workflows
│   ├── kraken2/            # Kraken2 -> Bracken -> MPA -> level tables
│   └── virgo2/             # VIRGO2 mapping, taxonomy, and annotation
├── skills/                # LLM-facing skill wrappers
│   ├── kraken2-flow/
│   └── virgo2-analysis/
├── docs/                  # Shared workflow contracts and conventions
└── templates/             # Scaffolds for new lightweight flows
```

## Design Goal

Each flow should be:

- usable directly by a human with Bash and a project config
- resumable by step without modifying scripts
- transparent through plain text logs and predictable outputs
- ready to be wrapped by an LLM skill
- portable across servers through explicit environment profiles and preflight checks

## Current Flows

### Kraken2

```bash
cd flows/kraken2
cp config_template.sh config.sh
vim config.sh
bash run_all.sh config.sh
```

### VIRGO2

```bash
cd flows/virgo2
cp config_template.sh config.sh
vim config.sh
bash step1_merge.sh config.sh
bash step2_map_parallel.sh config.sh
bash step3_compile.sh config.sh
bash step4_taxonomy.sh config.sh
bash step5_annotate.sh config.sh
```

## Flow Contract

New flows should follow the shared contract in [docs/flow-contract.md](docs/flow-contract.md).

The most important additions planned for every flow are:

- `preflight.sh` for environment, reference, input, and permission checks
- `status.sh` for resumable step status summaries
- `runtime/environments/profiles/` for server-specific conda and reference paths
- stable log and output conventions

