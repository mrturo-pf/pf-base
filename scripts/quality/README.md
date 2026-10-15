# Quality and documentation tools

- `check-language.py` — language-policy validation;
- `language-policy.txt` — allowed terminology and exclusions;
- `find-docs.sh` — documentation inventory;
- `search-words.sh` — read-only ecosystem search;
- `replace-words.py` — guarded word replacement;
- `search-words.jsonc.example` — local search configuration template.

The ignored `scripts/search-words.json` remains at the scripts root so existing
local configuration and `.gitignore` rules remain stable.
