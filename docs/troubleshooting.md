# Troubleshooting and operational notes

These issues were encountered or identified while developing the Sol/Terra proof of concept.

## Compose reports unset database-password variables

The environment file lives at the repository root, while the Compose file is in `compose/`. Pass the file explicitly:

```bash
docker compose --env-file .env -f compose/compose.yaml config --quiet
```

Confirm that `.env` exists and that `SOL_DB_PASSWORD` and `TERRA_DB_PASSWORD` are populated. Do not commit `.env`.

## Containers start but an HTTP port resets the connection

Uvicorn must listen on the container network interface, not only inside the container's loopback namespace. The working startup uses:

```text
uvicorn arkhe.app:create_app --factory --host 0.0.0.0 --port 8000
```

Use a shell argument-array command in Compose to avoid unintended line breaks changing how options are passed. A healthy database does not establish that the HTTP server is reachable.

## CLI help appears in Japanese

Arkhe can be configured using `ARKHE_LANG=en`. The Compose file sets that variable for the relevant processes. For an ad hoc CLI invocation:

```bash
docker compose --env-file .env -f compose/compose.yaml exec -e ARKHE_LANG=en terra-minter \
  arkhe --help
```

## A shell script reports `$'\r': command not found` or a broken `pipefail`

The file has Windows-style CRLF endings. Convert to LF:

```bash
sed -i 's/\r$//' scripts/verify.sh
file scripts/verify.sh
```

The repository should include `.gitattributes` such as `*.sh text eol=lf` and an editor configured for LF. On Debian, install the `file` utility with `sudo apt install file` if necessary.

## `arkhe shoulder redirect` unexpectedly removes delegation

The redirect value is an **optional argument with a destructive omission**. For example, running `arkhe shoulder redirect 3` removes that shoulder's resolution delegation; it does not show its current value.

Restore the redirect using the actual Sol shoulder ID:

```bash
arkhe shoulder redirect SOL_SHOULDER_ID \
  '303 http://localhost:8358/ark:$id'
```

This is an example of the Arkhe CLI command to execute *inside* `sol-minter`. Do not assume the numeric ID is `3`.

## Redirect tests return 405

`curl -I` sends **HEAD**, and this resolver did not accept HEAD. Use GET and display headers:

```bash
curl -i 'http://localhost:8258/ark:99999/s7YOUR_SUFFIX'
```

For a redirect trace use `curl -sS -D - -o /dev/null -L ...` (GET), or run `verify.sh` to avoid contacting the final target.

## Redirect chain ends with 404

The tested sequence was **Sol 303 → Terra 302 → example.org 404**. The last response comes from the intentionally non-existent demonstration target. Verify Arkhe's `Location` headers rather than asserting the final target returns 200.

## Incorrectly named API client

A typo in a client name does **not** require a database reset. First inspect the commands offered by the Arkhe version pinned for this PoC:

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe client --help
```

The tested recovery approach is to disable the mistaken client, then create the correctly named one. Replace `MISTYPED_CLIENT_NAME` with the actual name:

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe client disable MISTYPED_CLIENT_NAME
```

Look up **Terra's** numeric `/s7` shoulder ID (not Sol's):

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe shoulder list --naan 99999
```

Then create the intended client if it does not already exist:

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe client add federation-test 99999 \
  --shoulder TERRA_SHOULDER_ID --scopes "ark:mint"
```

Replace `TERRA_SHOULDER_ID` with the actual integer. Disabling a client prevents its credentials from being used but preserves its registration for audit; it is not the same as permanently deleting the record. If a key had already been issued to the incorrectly named client, ensure that it is no longer usable and revoke it individually where appropriate.

## Lost API key: issue a replacement and revoke the old credential

Arkhe distinguishes **clients** from **credentials**: the same client can have more than one API key. Issuing a new key does **not** necessarily invalidate the lost key.

### 1. Issue a replacement key

For the existing `federation-test` client:

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe client key federation-test
```

Copy the new key to a secure temporary location or paste it directly into the prompt of `./scripts/mint-test.sh`. Its plaintext value is shown on issuance and should not be committed, printed in screenshots, or placed in shell history.

### 2. Inspect credential records (read-only)

The CLI does not expose a credential-listing command in the version used for this PoC, so we inspected **Terra's** PostgreSQL ledger:

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-db \
  psql -U arkhe -d arkhe
```

Inside `psql`, inspect the schema before running a query (the query below reflects the tested model and may require adjustment on another Arkhe version):

```sql
\dt
\d credential
\d client

SELECT
    c.id,
    cl.client_id,
    c.kind,
    c.prefix,
    c.active
FROM credential AS c
JOIN client AS cl ON c.client_pk = cl.id
WHERE cl.client_id = 'federation-test'
ORDER BY c.id;
```

This shows administrative IDs and non-secret prefixes, **not the API key values**. Match the replacement key against its recorded prefix and client association. Although IDs are typically assigned in sequence, **do not revoke a credential solely because it has a lower ID**. If you cannot confidently distinguish the lost credential, stop and investigate rather than guessing.

Exit PostgreSQL with `\q`.

### 3. Revoke only the old credential

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe client revoke OLD_CREDENTIAL_ID
```

Replace `OLD_CREDENTIAL_ID` with the verified numeric credential ID, **not** the client name or API key.

### 4. Verify the rotation

Re-run the read-only query above. Confirm that the old credential's `active` value is `f` (false), while the replacement remains `t` (true). Then run:

```bash
./scripts/mint-test.sh
```

Supply the new key when prompted. A successful mint verifies the replacement can still authenticate. This procedure was exercised successfully during development of the PoC.

**Security:** Revocation is preferable to leaving an unknown usable key in circulation. Do not store API keys in `.env.example`, Git-tracked files, troubleshooting logs, screenshots or commit messages.

## Second checkout reuses the first installation

Cloning into a new folder does not guarantee new Docker resources. A hard-coded Compose project name can cause independent checkouts to share services and volumes. Use a separate project name, distinct published ports, and fresh credentials for isolated clean-clone tests. Check effective Compose configuration before `up`.

## Safe shutdown

```bash
docker compose --env-file .env -f compose/compose.yaml down
```

This normally preserves named volumes. **Do not add `-v`** unless deleting the ledger state is intentional, and ensure you're operating on the correct Compose project.
