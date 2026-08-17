# dsh-science-geophysics

**A geophysics research workbench for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)** — built for seismology / geomagnetism / geophysical-instrument projects. Forked from [dsh-science](https://github.com/biociao/dsh-science): the domain-agnostic engines are kept in sync with upstream (zero third-party deps), while the persona, skills and scaffolds are localized to geophysics.

- **ReAct research-loop engine** — `research_init/state/hypothesis/experiment/findings/phase/review/report`, state persisted in `research-manifest.json` (Question → Hypothesis → Experiment → Observe → Analyze → Conclude → Next question).
- **Versioned artifacts with provenance** — `artifact_save/list/show/diff/verify/deprecate/reproduce`: results stored as `artifacts/<name>/v<N>/` with per-file SHA-256, `artifact.json` provenance (command/inputs/environment/envFile) and append-only `provenance.md`.
- **12 research skills** — research-loop, science-project-setup, artifact-provenance, scientific-reviewer, literature-connector, parallel-delegation, manuscript-writing, **seismology-toolkit**, **geomagnetism-toolkit**, **instrument-dev**, conda-environments, data-inventory.

Install as a profile bundle (`dsh plugin add`) or as the **地球物理模式** agent preset. See README.zh.md for full documentation (Chinese).
