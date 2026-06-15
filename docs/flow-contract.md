# Lightweight Flow Contract

This document defines the expected shape of PROME lightweight bioinformatics flows.

## Required Files

Every flow should contain:

- `README.md`: human-facing quick start and outputs
- `config_template.sh`: project-level configuration template
- `run_all.sh`: runs the complete workflow when appropriate
- `step*.sh`: individually runnable and resumable steps
- `preflight.sh`: validates environment, references, inputs, permissions, and resources
- `status.sh`: reports completion, missing outputs, failed samples, and relevant logs

Existing flows may temporarily lack `preflight.sh` or `status.sh`; adding them is the main migration path.

## Configuration Layers

Prefer two configuration layers:

```text
env_profile.sh      # server-specific: conda, tools, reference databases, scheduler defaults
project_config.sh   # project-specific: input paths, output paths, samples, analysis parameters
```

The project config should not duplicate server-specific reference paths unless a project intentionally overrides them.

## Human CLI Contract

Humans should be able to run:

```bash
cp config_template.sh config.sh
vim config.sh
bash preflight.sh config.sh
bash run_all.sh config.sh
```

Every step should also work independently:

```bash
bash step2_example.sh config.sh
```

## LLM Skill Contract

An LLM skill should:

1. Identify the target flow and project inputs.
2. Select or create the appropriate environment profile.
3. Create a project config from `config_template.sh`.
4. Run `preflight.sh` before heavy computation.
5. Run `run_all.sh` or selected `step*.sh` commands.
6. Use `status.sh` and logs to summarize progress or diagnose failures.

## Step Behavior

Each step should:

- accept one config path argument
- create only its own output directories
- skip complete outputs using non-empty output checks
- return non-zero when required inputs are missing
- write sample-level logs under the configured log directory
- print failed sample names clearly

## Preflight Checks

`preflight.sh` should check:

- config files exist and can be sourced
- conda base and environment are available
- required commands are on `PATH`
- reference database paths exist
- database-specific parameter matches are valid
- input directory exists
- sample count is greater than zero
- paired FASTQ files exist for a small sample preview
- output directory is writable
- requested parallelism is plausible for the server

## Status Output

`status.sh` should produce human-readable text and, where practical, a machine-readable TSV or JSON summary with:

- step name
- expected sample count
- completed sample count
- failed or missing sample count
- key output paths
- log paths

