
# Development Notes

## Arkhe Source Version

- Upstream repository: https://github.com/RCOSDP/arkhe
- Commit SHA: 3e61cc73872ed3f7913349b4ddab18687b0febbc
- Version tag: v0.14.0-9-g3e61cc7
- Local application source modifications: None
- Local Compose modifications: Present, not required for PoC

## Architecture Decisions

- One Docker Compose project
- Two independent PostgreSQL ledgers
- Parent and child minter/resolver pairs
- API-key authentication for the demonstration
- Synthetic NAAN: 99999
- Delegated shoulder: /s7

## Implementation Notes

- Set ARKHE_LANG=en for English CLI output.
- Bind Uvicorn to 0.0.0.0 inside containers.
- Use GET, not HEAD, when testing resolution.
- Calling `arkhe shoulder redirect` without a redirect value removes the existing delegation.

## Outstanding Work

- Construct consolidated Compose deployment.
- Confirm independent database operation.
- Reproduce shoulder delegation.
- Automate minting and resolution verification.
