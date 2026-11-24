# Arkhe Shoulder Federation — Proof of Concept

A reproducible demonstration of **shoulder-level delegation** between two independently deployed [Arkhe](https://github.com/RCOSDP/arkhe) installations.

**Sol** delegates ARK shoulder `/s7` within synthetic NAAN `99999` to **Terra**. Terra mints identifiers and resolves them from its own PostgreSQL ledger; Sol recognises the delegated shoulder and redirects resolution requests to Terra. Both installations use the same pinned Arkhe application version, but **do not share a database**.

> **Status:** The local demonstration and an isolated clean-clone reproduction have passed. This is a proof of concept, not a production deployment or a general-purpose federation management service.

## What this proves

- Two independently initialised Arkhe ledgers can participate in a common NAAN with shoulder-level delegation.
- An authorised Terra client can mint an ARK under `ark:99999/s7...`.
- Terra directly resolves the minted ARK to its registered target (`302 Found`).
- Sol resolves the same ARK by delegating to Terra (`303 See Other`).
- Repeating an otherwise identical mint request with the same `request_id` returns the same identifier (idempotency).
- The setup, mint and resolution checks can be reproduced after cloning into an isolated deployment.

**Not demonstrated:** production security and availability, all failure scenarios, absence of all replicated records in the other ledger, cross-NAAN routing, and automated redirection of authenticated mint requests through Sol. Those require separate tests.

## Topology

```text
                  resolution request
                 ark:99999/s7...
                         |
                         v
                Sol resolver :8258
                  HTTP 303 redirect
                         |
                         v
               Terra resolver :8358
                  HTTP 302 redirect
                         |
                         v
            https://example.org/federation-test
                   (dummy target)

 Sol minter :8257                  Terra minter :8357
        |                                  |
 Sol PostgreSQL ledger             Terra PostgreSQL ledger
        (separate databases and persistent volumes)
```

Sol's delegated minter URL is configured to point to Terra's minter; this PoC's automated end-to-end test **submits mint requests directly to Terra**, rather than exercising client-side minting redirection through Sol.

The example uses `localhost` URLs because the HTTP client runs on the Docker host. These are not suitable federation destinations for remote clients.

## Requirements

- Docker with Compose support (for example Docker Desktop with WSL2)
- Git and access to the pinned upstream Arkhe source for the initial image build
- Bash, `curl`, `jq`, and `openssl` for the mint/verification scripts
- Free host ports `8257`, `8258`, `8357`, and `8358` (or adjust the deployment and script URLs)

The repository's `.env.example` specifies the required variables, including `ARKHE_REF` (the exact, tested upstream commit). Use the **recorded full commit SHA**, not a floating branch, for reproducibility. An upstream commit pin does not by itself guarantee byte-for-byte reproducible container images.

## Quick start

Run from the **repository root**. Do not copy credential files from an existing installation.

### 1. Configure local environment

```bash
cp .env.example .env
```

Edit `.env` and set distinct, non-placeholder passwords for `SOL_DB_PASSWORD` and `TERRA_DB_PASSWORD`. Confirm `ARKHE_REF` is set to the pinned commit specified by the project. The local `.env` file must remain untracked.

### 2. Start independent deployments

```bash
docker compose --env-file .env -f compose/compose.yaml config --quiet
docker compose --env-file .env -f compose/compose.yaml up -d --build
docker compose --env-file .env -f compose/compose.yaml ps
```

Check the four HTTP endpoints:

```bash
curl -i http://localhost:8257/healthz
curl -i http://localhost:8258/healthz
curl -i http://localhost:8357/healthz
curl -i http://localhost:8358/healthz
```

Each should return HTTP `200 OK` after startup. Sol and Terra must have **separate PostgreSQL volumes**.

### 3. Configure the shared NAAN and delegated shoulder

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

`setup.sh` registers synthetic NAAN `99999`, ensures shoulder `/s7` exists in both ledgers, identifies their database-local shoulder IDs, and configures Sol's delegation to Terra. It can be rerun against existing records; it also **reapplies Sol's configured resolution redirect**, so treat it as a configuration-changing script.

### 4. Create Terra's minting client and API key

Client creation and key issuance are deliberately **manual**, not part of `setup.sh`.

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe shoulder list --naan 99999
```

Record Terra's numeric shoulder ID. Substitute it in the next command:

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe client add federation-test 99999 \
  --shoulder TERRA_SHOULDER_ID --scopes 'ark:mint'

docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe client key federation-test
```

The key is a secret. Save it securely, **never commit it**, and do not paste it into issue reports. If the named client already exists, do not run `client add` again; issue a key for that existing client as appropriate.

### 5. Mint and verify

```bash
./scripts/mint-test.sh
```

### Verify an existing ARK

You can run the resolution verification independently against an ARK that has **already been minted and registered in Terra's ledger**.

```bash
./scripts/verify.sh ark:99999/s7YOUR_SUFFIX
```

Replace `YOUR_SUFFIX` with the suffix of an actual ARK previously minted by Terra.

**An arbitrary or invented identifier will not pass this test.** Terra must have a corresponding record with the expected target URL.

The identifier does **not** need to exist in Sol's ledger. Sol only needs to recognise `/s7` as a delegated shoulder and redirect resolution requests to Terra.

For a fresh installation, use:

```bash
./scripts/mint-test.sh
```

This creates a new ARK on Terra and automatically invokes `verify.sh` using the newly issued identifier.

**Recommended workflow:** Use `mint-test.sh` for initial acceptance testing and `verify.sh` when checking an existing identifier without minting another.

To exercise mint idempotency, run the same request ID **twice**, without changing the payload:

```bash
./scripts/mint-test.sh repeatable-test-001
./scripts/mint-test.sh repeatable-test-001
```

Both runs should yield the **same ARK**. Use a fresh request ID if you have previously used this name with a different payload.

## What success looks like

```text
Terra mint request: success
Terra resolution:    302 -> registered target
Sol resolution:      303 -> Terra resolver
```

The target `https://example.org/federation-test` is deliberately synthetic and may return HTTP `404`. **That does not mean federation failed**: verification checks Arkhe's two redirects without requesting the final target.

## Repeatability, cleanup and isolation

A second Git clone is **not automatically a new Docker deployment**. This project's Compose file declares a project name, so another checkout using the same name can reuse the same containers and volumes. For an isolated clean-clone test, use a distinct Compose project name **and distinct host ports**, then adjust `SOL_RESOLVER`, `TERRA_MINTER` and `TERRA_RESOLVER` for the scripts. See [the manual walkthrough](docs/manual-walkthrough.md).

Never run `docker compose down -v` unless you deliberately intend to delete that project's persistent PostgreSQL volumes. Normal `docker compose down` leaves named volumes intact.

## Documentation

- [Architecture and authority boundaries](docs/architecture.md)
- [Manual federation walkthrough](docs/manual-walkthrough.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Observed test results and outstanding tests](docs/test-results.md)

## Scope and licence

This PoC documents Arkhe's namespace federation; it does not address research metadata interchange, replica management, scheduling, or production persistent-identifier governance. Names and NAANs are synthetic examples.

The **repository's own** `LICENSE` governs its original configuration, scripts and documentation. Arkhe is a separate upstream project: consult [its repository](https://github.com/RCOSDP/arkhe) for its licence and documentation. A pinned upstream dependency does not imply this repository maintains or controls Arkhe.
