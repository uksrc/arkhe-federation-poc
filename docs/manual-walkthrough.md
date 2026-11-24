# Manual shoulder-delegation walkthrough

These are the individual operations represented by `scripts/setup.sh`, followed by manual client creation and the verification steps. Commands assume a running deployment and that you are in the repository root.

> These are **state-changing operations**. On an already configured installation, use `setup.sh` for its existing-record checks rather than blindly re-executing every manual command. Do not use these instructions against production ledgers.

## 1. Register synthetic NAAN on Sol

```bash
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe naan add 99999 'Federation Organisation'

docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe naan list
```

## 2. Create Sol's shoulder

```bash
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe shoulder add 99999 /s7 --note 'Delegated to Terra'

docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe shoulder list --naan 99999
```

Record **Sol's local numeric shoulder ID**.

## 3. Initialise Terra's shoulder

The original manual procedure used Arkhe's `onboard` command on Terra:

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe onboard 99999 'Federation Organisation' \
  --shoulder /s7 --commitment permanent-dynamic

docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe naan list

docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe shoulder list --naan 99999
```

`permanent-dynamic` declares a persistence commitment associated with onboarding; this synthetic example is not an institutional preservation policy. In the automated setup, the NAAN-existence checks and onboarding sequence are handled by the script.

## 4. Configure delegation at Sol

Replace `SOL_SHOULDER_ID` with the numeric ID discovered in Step 2.

```bash
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe shoulder status SOL_SHOULDER_ID delegated \
  --minter http://localhost:8357

docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe shoulder redirect SOL_SHOULDER_ID \
  '303 http://localhost:8358/ark:$id'
```

**Critical:** Calling `arkhe shoulder redirect SOL_SHOULDER_ID` with **no redirect argument removes the redirect**. It is not a read-only inspection command. Keep the single quotes around `$id` so Bash does not expand it.

Confirm Sol's delegated status:

```bash
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe shoulder list --naan 99999
```

The summary may not show the redirect template; verify behaviour through HTTP.

## 5. Register a shoulder-scoped Terra client

Look up **Terra's** numeric shoulder ID:

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe shoulder list --naan 99999
```

Create a client with the `ark:mint` scope, then issue a key. Replace the placeholder ID:

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe client add federation-test 99999 \
  --shoulder TERRA_SHOULDER_ID --scopes 'ark:mint'

docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe client key federation-test
```

Keep the key secret. A new key does not necessarily revoke previous credentials. See [Troubleshooting](troubleshooting.md) for safe credential cleanup.

## 6. Mint and resolve

Mint and test automatically:

```bash
./scripts/mint-test.sh
```

Or verify a previously minted identifier without issuing another:

```bash
./scripts/verify.sh ark:99999/s7YOUR_SUFFIX
```

For manual inspection (using a real minted ARK):

```bash
curl -i 'http://localhost:8358/ark:99999/s7YOUR_SUFFIX'
curl -i 'http://localhost:8258/ark:99999/s7YOUR_SUFFIX'
```

Expect Terra `302` to the registered target and Sol `303` to Terra. For a complete GET redirect trace:

```bash
curl -sS -D - -o /dev/null -L --max-redirs 2 \
  'http://localhost:8258/ark:99999/s7YOUR_SUFFIX'
```

The synthetic final target may return 404. Avoid `curl -I` here: HEAD produced `405 Method Not Allowed` in this deployment.

## 7. Clean-clone acceptance test

To demonstrate independent reproducibility, create a second clone. **Do not merely run the same Compose project name in another folder.** Use a distinct Compose project name and nonconflicting host ports. In the successfully tested isolated copy, ports were temporarily changed to:

| Service | Initial PoC | Isolated clone |
| --- | --- | --- |
| Sol minter | 8257 | 8457 |
| Sol resolver | 8258 | 8458 |
| Terra minter | 8357 | 8557 |
| Terra resolver | 8358 | 8558 |

In the isolated clone, before setup and minting, export:

```bash
export SOL_RESOLVER=http://localhost:8458
export TERRA_MINTER=http://localhost:8557
export TERRA_RESOLVER=http://localhost:8558
```

Then start the cloned deployment using its own `.env`, run `./scripts/setup.sh`, create a new Terra client/key, and run `./scripts/mint-test.sh`. The isolated clean-clone exercise was reported successful on 24 November 2026.

**Note:** Docker Compose’s `-p` flag explicitly overrides `name:` in the file, so it can also be used to isolate the clone. You still need non-conflicting host ports and matching script URL variables. The original clean test instead changed the Compose `name:` and host ports in the cloned copy. Inspect `docker compose config` and `docker compose ps` before starting services.
