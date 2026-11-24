
#!/usr/bin/env bash
set -euo pipefail

# Arkhe shoulder federation verification
# Usage: ./scripts/verify.sh ark:99999/s7...

SOL_RESOLVER="${SOL_RESOLVER:-http://localhost:8258}"
TERRA_RESOLVER="${TERRA_RESOLVER:-http://localhost:8358}"
EXPECTED_TARGET="${EXPECTED_TARGET:-https://example.org/federation-test}"

ARK="${1:-}"

if [[ ! "$ARK" =~ ^ark:99999/s7[a-zA-Z0-9]+$ ]]; then
    echo "[FAIL] Supply a valid test ARK under 99999/s7"
    echo "Usage: $0 ark:99999/s7..."
    exit 1
fi

command -v curl >/dev/null || {
    echo "[FAIL] curl is required"
    exit 1
}

pass() {
    echo "[PASS] $1"
}

fail() {
    echo "[FAIL] $1"
    exit 1
}

# Perform a GET request without following redirects.
# Record the HTTP status and Location header.
check_redirect() {
    local url="$1"
    local expected_status="$2"
    local expected_location="$3"
    local description="$4"

    local result status location

    result=$(curl --silent --show-error \
        --max-time 10 \
        --output /dev/null \
        --write-out '%{http_code}\n%{redirect_url}' \
        "$url") || fail "$description: request failed"

    status="${result%%$'\n'*}"
    location="${result#*$'\n'}"

    if [[ "$status" != "$expected_status" ]]; then
        fail "$description: expected HTTP $expected_status, got $status"
    fi

    if [[ "$location" != "$expected_location" ]]; then
        echo "  Expected: $expected_location"
        echo "  Actual:   $location"
        fail "$description: incorrect redirect destination"
    fi

    pass "$description"
}

echo "========================================"
echo "ARKHE FEDERATION VERIFICATION"
echo "========================================"
echo "ARK: $ARK"
echo

check_redirect \
    "$TERRA_RESOLVER/$ARK" \
    "302" \
    "$EXPECTED_TARGET" \
    "Terra resolves ARK to registered target"

check_redirect \
    "$SOL_RESOLVER/$ARK" \
    "303" \
    "$TERRA_RESOLVER/$ARK" \
    "Sol delegates resolution to Terra"

echo
echo "========================================"
echo "RESULT: FEDERATION VERIFIED"
echo "========================================"
