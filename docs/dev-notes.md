
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


## Manual Stages

=====================
#### Establish test naan
=====================

We need to set the NAAN in each of the Arkhe instances
99999 is the test NAAN that will be used by each

The following registers the NAAN in sol, we will come back to do this in Terra and it will be in a slightly differnt way
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
arkhe naan add 99999 "Federation Organisation"

Use the followsing to check the NAAN is successfully registered:
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
arkhe naan list


Next were going to set up the shoulder /s7, this regrads a project or suborganisation within the ARK NAAN
Sol will delegate to Terra for this
in Terra we will set up the NAAN and shoulder at the same time using onboard allowing us to specify the containment type

docker compose --env-file .env -f ./compose/compose.yaml exec sol-minter \
arkhe shoulder add 99999 /s7 --note "Delegated to Terra"

Then again were going to chech the shoulder is listed
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
arkhe shoulder list --naan 99999


we need to write down the numeric shoulder id for later

we now need to onboard the /s7 shoulder in the terra-minter
docker compose --env-file .env -f ./compose/compose.yaml exec terra-minter \
arkhe onboard 99999 "Federation Organisation" --shoulder /s7 --commitment permanent-dynamic

This time were going to check the NAAN and shoulder have both been successfully registered:
docker compose --env-file .env -f compose/compose.yaml exec terra-minter \
arkhe shoulder list


Next up we need to set the delegation from Sol to Terra; 
First we need to set the delegated minting authroity
Note before running: where # is listed below we're going to replace that with the numeric shoulder id that we wrote down before.
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \
arkhe shoulder status # delegated --minter http://localhost:8357


then we need to configure the resolution delegation 
docker compose --env-file .env -f compose/compose.yaml exec sol-minter \ 
arkhe shoulder redirect # '303 http://localhost:8358/ark:$id'

