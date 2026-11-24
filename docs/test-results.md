# Test results and evidence

This document records the **user-observed outcomes** of the local Sol/Terra proof of concept. It is not a test log generated directly from CI. For an independently auditable record, retain non-secret test output and the exact tested Git commit/tag alongside these notes.

## Environment

- Repository: Arkhe shoulder federation proof of concept
- Installation names: Sol and Terra
- Deployment: one Docker Compose project, two independent PostgreSQL services/volumes
- Arkhe source: pinned upstream commit recorded in `.env.example` / project notes (insert actual SHA in the repository)
- Test NAAN: `99999` (synthetic)
- Delegated shoulder: `/s7`
- Sol ports: minter `8257`, resolver `8258`
- Terra ports: minter `8357`, resolver `8358`
- Host environment: Docker Desktop and Debian WSL2

## Observed outcomes

| Test | Observation | Assessment |
| --- | --- | --- |
| Health checks | Four minter/resolver HTTP health endpoints returned `200 OK` | Passed |
| Manual Terra mint | Shoulder-scoped Terra client issued an ARK under `99999/s7` | Passed |
| Direct Terra resolution | `302 Found` with Location pointing to the registered dummy target | Passed |
| Sol delegated resolution | `303 See Other` with Location pointing to Terra and preserving the full ARK | Passed |
| Redirect chain | `303` Sol → `302` Terra → synthetic target `404` | Federation passed; final `404` expected |
| `verify.sh` | Both redirect assertions passed against a pre-existing minted ARK | Passed |
| `mint-test.sh` | Minted and invoked `verify.sh` successfully | Passed |
| Mint idempotency | Repeated identical request ID/payload returned the same ARK | Passed |
| Credential rotation | Old credential was revoked in PostgreSQL; replacement key successfully minted | Passed |
| `setup.sh` on existing ledgers | Found existing NAANs/shoulders, discovered correct local IDs, completed without duplicate namespace records | Passed |
| Isolated clean-clone deployment | Fresh independent deployment, setup, client creation and mint/verification completed as expected | Passed — user-reported 24 Nov 2026 |

The original manual redirect trace included:

```http
HTTP/1.1 303 See Other
Location: http://localhost:8358/ark:99999/s7btn1gtqqf

HTTP/1.1 302 Found
Location: https://example.org/federation-test

HTTP/2 404
```

The final `404` is from the dummy third-party URL, **not** Arkhe.

## What these tests do not prove

- Sol lacks every possible reference to the Terra-minted ARK; independent databases are configured, but an explicit database-absence assertion is not in `verify.sh`.
- Minting delegation through **Sol's mint API** returns a verified expected response; the automated mint request is sent directly to Terra.
- Behaviour during container, database, network, or destination-site failures.
- Enforcement of all namespace permission boundaries and access-control edge cases.
- Long-term persistence after stale database restoration.
- Operational readiness: backups, monitoring, alerts, security audit, HA or incident response.

## Final acceptance statement

The proof of concept successfully demonstrates **shoulder-delegated ARK resolution across independent Arkhe ledgers**, paired with authorised minting on Terra. The isolated clean-clone test provides evidence that the described deployment and scripts can reproduce the behaviour without relying on the original development database state.

This conclusion is limited to the synthetic local test configuration and its documented acceptance criteria.
