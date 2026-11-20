# Establishing Shoulder Delegation

This walkthrough configures shoulder-level federation between two independent Arkhe installations, **Sol** and **Terra**.

Both installations use the synthetic NAAN `99999` and shoulder `/s7`. Sol delegates minting authority and resolution for this shoulder to Terra.

All commands are executed from the root directory of the proof-of-concept repository.

## 1. Register the test NAAN on Sol

First, register NAAN `99999` in Sol.

```bash
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe naan add 99999 "Federation Organisation"
```

Verify that it has been registered:

```bash
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe naan list
```

We will register the same NAAN on Terra later using `arkhe onboard`, which also establishes the organisational information and shoulder.

## 2. Create the delegated shoulder on Sol

Create shoulder `/s7` under NAAN `99999`.

A shoulder represents an allocated namespace within a NAAN. It can be associated with a particular project, organisation or other delegated responsibility.

```bash
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe shoulder add 99999 /s7 --note "Delegated to Terra"
```

Verify that the shoulder exists:

```bash
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe shoulder list --naan 99999
```

**Record the numeric shoulder ID assigned by Sol.** We will need it when configuring delegation. This is a database-local identifier and should not be assumed to match Terra's shoulder ID.

## 3. Onboard the NAAN and shoulder on Terra

We now configure Terra using the `onboard` command.

This establishes the relevant organisational information and shoulder, including an explicit permanence commitment.

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe onboard 99999 "Federation Organisation" \
  --shoulder /s7 \
  --commitment permanent-dynamic
```

The `permanent-dynamic` commitment indicates a commitment to persistent identification while allowing the identified resource to change. It is appropriate for this synthetic proof of concept.

For production deployments, permanence commitments should reflect an agreed institutional policy.

Verify the NAAN:

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe naan list
```

Verify the shoulder:

```bash
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
  arkhe shoulder list --naan 99999
```

At this point, Sol and Terra should both recognise NAAN `99999` and shoulder `/s7`, but they retain entirely independent PostgreSQL ledgers.

## 4. Configure delegated minting authority

Sol must recognise that minting responsibility for `/s7` has been delegated to Terra.

In the following command, replace `SOL_SHOULDER_ID` with the numeric shoulder ID recorded in Step 2.

```bash
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe shoulder status SOL_SHOULDER_ID delegated \
  --minter http://localhost:8357
```

This marks Sol's shoulder as delegated and specifies Terra's minter as the destination for redirected minting requests.

The URL uses `localhost` because this proof of concept is intended to be exercised from the Docker host. A distributed deployment would require a client-reachable hostname.

## 5. Configure resolution delegation

Next, configure Sol to redirect resolution requests for `/s7` to Terra's resolver.

Again, replace `SOL_SHOULDER_ID` with Sol's numeric shoulder ID.

```bash
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe shoulder redirect SOL_SHOULDER_ID \
  '303 http://localhost:8358/ark:$id'
```

The `303` specifies the HTTP redirect status, while `$id` is an Arkhe template placeholder for the requested identifier.

**Important:** Retain the single quotation marks around the redirect template. Otherwise, Bash may attempt to expand `$id` as a shell variable.

**Caution:** Calling `arkhe shoulder redirect SOL_SHOULDER_ID` without a redirect argument removes the existing resolution delegation. It does not display the current configuration.

## 6. Verify the shoulder status

Check Sol's shoulder configuration:

```bash
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
  arkhe shoulder list --naan 99999
```

The `/s7` shoulder should now have delegated status.

The list output does not necessarily display the configured resolution redirect. We will verify that behaviour through an actual HTTP request after minting an identifier on Terra.

## Expected configuration

| Property | Sol | Terra |
|---|---|---|
| NAAN | 99999 | 99999 |
| Shoulder | /s7 | /s7 |
| Role | Delegating authority | Delegated minting authority |
| PostgreSQL ledger | Independent | Independent |
| Minter port | 8257 | 8357 |
| Resolver port | 8258 | 8358 |

## Next steps

The delegation configuration is now established.

The next stage will:

1. Create an API client authorised to mint under `/s7` on Terra.
2. Mint a test ARK using Terra.
3. Verify direct resolution through Terra.
4. Verify that Sol delegates resolution to Terra.
5. Confirm that the complete HTTP redirect chain functions correctly.

These tests will provide functional evidence that shoulder delegation operates across independently maintained Arkhe ledgers.
