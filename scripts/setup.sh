
#!/usr/bin/env bash
set -euo pipefail

# Configure Sol -> Terra shoulder delegation.
# Run from anywhere within the repository.
#
# This script is intended for the synthetic PoC
# namespace, not a production Arkhe installation.

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

NAAN="99999"
SHOULDER="/s7"
ORG="Federation Organisation"

TERRA_MINTER="${TERRA_MINTER:-http://localhost:8357}"
TERRA_RESOLVER="${TERRA_RESOLVER:-http://localhost:8358}"

compose() {
    (
        cd "$ROOT"
        docker compose --env-file .env \
            -f compose/compose.yaml "$@"
    )
}

arkhe() {
    local service="$1"
    shift

    compose exec -T "$service" arkhe "$@"
}

fail() {
    echo "[FAIL] $*" >&2
    exit 1
}

pass() {
    echo "[PASS] $*"
}

# Look up a shoulder and return:
# numeric_id status
shoulder_record() {
    local service="$1"

    arkhe "$service" shoulder list --naan "$NAAN" |
        awk -v name="${NAAN}${SHOULDER}" '
            $2 == name { print $1, $3 }
        '
}

ensure_naan() {
    local service="$1"

    if arkhe "$service" naan list |
        awk -v naan="$NAAN" '$1 == naan { found=1 }
                              END { exit !found }'; then
        pass "$service: NAAN already registered"
    else
        arkhe "$service" naan add "$NAAN" "$ORG"
        pass "$service: NAAN registered"
    fi
}

echo "======================================"
echo "ARKHE FEDERATION SETUP"
echo "======================================"

command -v docker >/dev/null ||
    fail "Docker is not installed"

[[ -f "$ROOT/.env" ]] ||
    fail "Missing .env file"

compose config --quiet ||
    fail "Invalid Compose configuration"

# Check both installations before making changes.
for service in sol-minter terra-minter; do
    compose exec -T "$service" arkhe --help \
        >/dev/null ||
        fail "$service is unavailable"
done

# 1. Register NAAN in both ledgers.
ensure_naan sol-minter
ensure_naan terra-minter

# 2. Ensure Sol has the delegated shoulder.
SOL_RECORD="$(shoulder_record sol-minter)"

if [[ -z "$SOL_RECORD" ]]; then
    arkhe sol-minter shoulder add \
        "$NAAN" "$SHOULDER" \
        --note "Delegated to Terra"
    SOL_RECORD="$(shoulder_record sol-minter)"
fi

read -r SOL_ID SOL_STATUS <<< "$SOL_RECORD"

[[ "$SOL_ID" =~ ^[0-9]+$ ]] ||
    fail "Could not determine Sol shoulder ID"

# 3. Ensure Terra has its local shoulder.
TERRA_RECORD="$(shoulder_record terra-minter)"

if [[ -z "$TERRA_RECORD" ]]; then
    arkhe terra-minter onboard \
        "$NAAN" "$ORG" \
        --shoulder "$SHOULDER" \
        --commitment permanent-dynamic

    TERRA_RECORD="$(shoulder_record terra-minter)"
fi

read -r TERRA_ID TERRA_STATUS <<< "$TERRA_RECORD"

[[ "$TERRA_ID" =~ ^[0-9]+$ ]] ||
    fail "Could not determine Terra shoulder ID"

[[ "$TERRA_STATUS" == "active" ]] ||
    fail "Terra shoulder is not active: $TERRA_STATUS"

pass "Sol shoulder ID: $SOL_ID"
pass "Terra shoulder ID: $TERRA_ID"

# 4. Establish minting delegation.
if [[ "$SOL_STATUS" != "delegated" ]]; then
    arkhe sol-minter shoulder status \
        "$SOL_ID" delegated \
        --minter "$TERRA_MINTER"

    pass "Sol minting delegation configured"
else
    pass "Sol shoulder already delegated"
fi

# 5. Explicitly configure resolution forwarding.
# Never omit the redirect argument: that clears it.
arkhe sol-minter shoulder redirect \
    "$SOL_ID" \
    "303 ${TERRA_RESOLVER}/ark:\$id"

pass "Sol resolution redirect configured"

echo
echo "======================================"
echo "SETUP COMPLETE"
echo "======================================"
echo "NAAN:           $NAAN"
echo "Shoulder:       $SHOULDER"
echo "Sol shoulder:   $SOL_ID"
echo "Terra shoulder: $TERRA_ID"
echo
echo "Next: configure Terra's minting client"
echo "and run mint-test.sh"
