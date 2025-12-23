# Fast Documentation Model Overview

Updated: 2025-12-22
Purpose: define a small, fast model dedicated to documentation updates.

## Placement in the Model Hierarchy
oracle-council routes documentation tasks to a small oracle-nayru specialist:
- impa-scribe (fast doc updates, 1.5B or 3B)

## Scope
- Update plans, guides, and catalogs.
- Keep naming rules consistent across docs.
- Maintain cross-references and remove dead links.
- Avoid code changes; defer technical decisions to domain specialists.

## Domains
- docs_explain
- code_intel_lsp (for references, labels, and symbol lookups)
- tools_hafs (optional, when documenting CLI usage)

## Model Sizing
- 1.5B for speed; 3B if more context fidelity is needed.
- Keep this model lightweight and always-on for quick doc edits.

## Routing and Usage
- oracle-council sends doc-update requests to impa-scribe.
- oracle-moe and triforce-moe remain for synthesis tasks; they are not required for doc updates.
- master-sword and fierce-deity are reserved for cross-domain reasoning, not routine doc edits.

## Guardrails
- Use canonical names: master-sword, fierce-deity, oracle-moe, triforce-moe.
- Submodels never use the oracle- prefix.
- Prefer concise changes; avoid drifting into new design work.
