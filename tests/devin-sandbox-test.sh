#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
launcher="$repo_root/scripts/devin-sandbox"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
test_root="$(cd "$test_root" && pwd -P)"

mkdir -p "$test_root/bin" "$test_root/state" "$test_root/My_Project"
printf 'test credential\n' > "$test_root/credentials.toml"

cat > "$test_root/bin/sbx" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%q ' "$@" >> "$FAKE_SBX_LOG"
printf '\n' >> "$FAKE_SBX_LOG"

command_name="${1:-}"
shift || true

case "$command_name" in
  inspect)
    name="${1:-}"
    [[ -f "$FAKE_SBX_STATE/$name" ]] || exit 1
    IFS='|' read -r agent workspace < "$FAKE_SBX_STATE/$name"
    printf '  Name:       %s\n  Agent:      %s\n  Workspace:  %s\n' "$name" "$agent" "$workspace"
    ;;
  create)
    name=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --name) name="$2"; shift 2 ;;
        --kit|--static-mcp) shift 2 ;;
        devin)
          shift
          workspace="${1%%:*}"
          workspace="$(cd "$workspace" && pwd -P)"
          printf 'devin|%s\n' "$workspace" > "$FAKE_SBX_STATE/$name"
          exit 0
          ;;
        *) shift ;;
      esac
    done
    exit 1
    ;;
  policy)
    printf '{"allowed": %s}\n' "${FAKE_POLICY_ALLOWED:-false}"
    ;;
  rm)
    [[ "${1:-}" == --force ]] && shift
    rm -f "$FAKE_SBX_STATE/${1:-}"
    ;;
  cp|exec|run)
    ;;
  *)
    printf 'unexpected fake sbx command: %s\n' "$command_name" >&2
    exit 1
    ;;
esac
EOF
chmod 755 "$test_root/bin/sbx"

export PATH="$test_root/bin:$PATH"
export FAKE_SBX_STATE="$test_root/state"
export FAKE_SBX_LOG="$test_root/sbx.log"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

"$launcher" --help >/dev/null 2>&1 || fail "--help should exit successfully"

FAKE_POLICY_ALLOWED=false "$launcher" \
  --credentials "$test_root/credentials.toml" \
  --static-mcp notion,linear \
  --no-attach \
  "$test_root/My_Project"

generated_name="$(find "$test_root/state" -maxdepth 1 -type f -exec basename {} \;)"
[[ "$generated_name" =~ ^devin-my-project-[0-9]+$ ]] \
  || fail "generated name is invalid or lacks a path hash: $generated_name"
grep -Fq -- '--static-mcp notion\,linear' "$FAKE_SBX_LOG" \
  || fail "static MCP selection was not passed to sbx create"

mkdir -p "$test_root/other/My_Project"
printf 'devin|%s\n' "$test_root/My_Project" > "$test_root/state/shared-name"
if FAKE_POLICY_ALLOWED=false "$launcher" \
  --credentials "$test_root/credentials.toml" \
  --name shared-name --no-attach "$test_root/other/My_Project" \
  >"$test_root/collision.out" 2>&1; then
  fail "launcher reused a sandbox belonging to another workspace"
fi
grep -Fq 'belongs to' "$test_root/collision.out" \
  || fail "workspace collision did not produce a useful error"

printf 'devin|%s\n' "$test_root/My_Project" > "$test_root/state/policy-test"
: > "$FAKE_SBX_LOG"
if FAKE_POLICY_ALLOWED=true "$launcher" \
  --credentials "$test_root/credentials.toml" \
  --name policy-test --no-attach "$test_root/My_Project" \
  >"$test_root/policy.out" 2>&1; then
  fail "launcher copied credentials with unrestricted egress"
fi
grep -Fq 'refusing to copy credentials' "$test_root/policy.out" \
  || fail "unrestricted egress did not produce a useful error"
if grep -Eq '^cp ' "$FAKE_SBX_LOG"; then
  fail "credentials were copied before the policy check"
fi

mkdir -p "$test_root/rejected"
: > "$FAKE_SBX_LOG"
if FAKE_POLICY_ALLOWED=true "$launcher" \
  --credentials "$test_root/credentials.toml" \
  --name rejected-new --no-attach "$test_root/rejected" \
  >"$test_root/rejected.out" 2>&1; then
  fail "new sandbox with unrestricted egress was accepted"
fi
[[ ! -e "$test_root/state/rejected-new" ]] \
  || fail "new sandbox was left behind after its policy was rejected"
grep -Eq '^rm --force rejected-new' "$FAKE_SBX_LOG" \
  || fail "rejected new sandbox was not cleaned up"

FAKE_POLICY_ALLOWED=true "$launcher" \
  --credentials "$test_root/credentials.toml" \
  --name policy-test --allow-unrestricted-egress --no-attach \
  "$test_root/My_Project"
grep -Eq '^cp ' "$FAKE_SBX_LOG" \
  || fail "explicit unrestricted-egress override did not provision credentials"

printf 'devin-sandbox launcher tests passed\n'
