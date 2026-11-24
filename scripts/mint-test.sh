
#!/usr/bin/env bash
set -euo pipefail

# Arkhe Federation PoC — Mint and verify
#
# Usage:
#   ./scripts/mint-test.sh [request_id]
#
# Supply a request_id to repeat an idempotency test.
# Otherwise, a unique request_id is generated.

TERRA_MINTER="${TERRA_MINTER:-http://localhost:8357}"
EXPECTED_TARGET="${EXPECTED_TARGET:-https://example.org/federation-test}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

pass() {
    echo "[PASS] $1"
}

fail() {
    echo "[FAIL] $1" >&2
    exit 1
}

# Check prerequisites before attempting to mint.
for cmd in curl jq openssl mktemp; do
    command -v "$cmd" >/dev/null 2>&1 ||
        fail "Required command not found: $cmd"
done

[[ -x "$SCRIPT_DIR/verify.sh" ]] ||
    fail "verify.sh not found or not executable"

# Obtain the API key without embedding it in the script.
if [[ -z "${TERRA_API_KEY:-}" ]]; then
    [[ -t 0 ]] ||
        fail "Set TERRA_API_KEY when running non-interactively"

    read -rsp "Terra API key: " TERRA_API_KEY
    echo
fi

# Confirm a non-empty API key was received.
[[ -n "$TERRA_API_KEY" ]] ||
    fail "No API key supplied"

echo "[INFO] API key recieved"

# Generate a unique request ID unless one was supplied.
if (( $# > 1 )); then
    fail "Usage: $0 [request_id]"
fi

REQUEST_ID="${1:-sol-terra-$(openssl rand -hex 16)}"

# Construct the request using jq to ensure valid JSON.
PAYLOAD=$(jq -n \
    --arg request_id "$REQUEST_ID" \
    --arg target "$EXPECTED_TARGET" \
    '{
        shoulder: "/s7",
        title: "Sol Terra Federation Test",
        who: "Arkhe Federation PoC",
        when: "2026",
        url: $target,
        request_id: $request_id
    }')

# Store the response temporarily for safe JSON parsing.
RESPONSE_FILE=$(mktemp)
trap 'rm -f "$RESPONSE_FILE"' EXIT

echo "========================================"
echo "ARKHE FEDERATION MINT TEST"
echo "========================================"
echo "Minter:     $TERRA_MINTER"
echo "Request ID: $REQUEST_ID"
echo

# Do not follow HTTP redirects when sending credentials.
HTTP_STATUS=$(curl --silent --show-error \
    --max-time 30 \
    --output "$RESPONSE_FILE" \
    --write-out '%{http_code}' \
    --request POST "$TERRA_MINTER/api/mint" \
    --header "Authorization: Bearer $TERRA_API_KEY" \
    --header "Content-Type: application/json" \
    --data "$PAYLOAD") ||
    fail "Mint request failed"

case "$HTTP_STATUS" in
    201)
        pass "Terra minted a new ARK"
        ;;
    200)
        pass "Terra returned an existing ARK (idempotent request)"
        ;;
    *)
        echo "HTTP status: $HTTP_STATUS" >&2
        fail "Mint request was not successful"
        ;;
esac

# Extract and validate the minted ARK.
ARK=$(jq -r '.ark // empty' "$RESPONSE_FILE") ||
    fail "Could not parse the mint response"

[[ "$ARK" =~ ^ark:99999/s7[a-zA-Z0-9]+$ ]] ||
    fail "Unexpected or missing ARK: $ARK"

pass "ARK returned: $ARK"

echo
echo "Running federation verification..."
echo

EXPECTED_TARGET="$EXPECTED_TARGET" \
    "$SCRIPT_DIR/verify.sh" "$ARK" ||
    fail "Federation verification failed"

echo
echo "========================================"
echo "RESULT: MINT AND FEDERATION VERIFIED"
echo "========================================"
echo "ARK: $ARK"
