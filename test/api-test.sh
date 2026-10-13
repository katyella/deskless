#!/usr/bin/env bash
# Runs deskless's laptop commands (up, down, list) against a local mock of the Hetzner API.
# Nothing real is created. The mock's servers use TEST-NET addresses, which never answer SSH.
#   bash test/api-test.sh
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
port=$((20000 + RANDOM % 20000))
python3 -I "$here/hetzner-mock.py" "$port" & mock=$!
trap 'kill $mock 2>/dev/null; rm -rf "$work"' EXIT
sleep 1

# A copy that waits one round for SSH instead of forty, so the create test is quick.
sed 's/for i in $(seq 1 40)/for i in $(seq 1 1)/; s/    sleep 5$/    sleep 0/' "$here/../deskless" > "$work/deskless"
chmod +x "$work/deskless"
export HCLOUD_API=http://127.0.0.1:$port/v1 HCLOUD_TOKEN=good
cb() { "$work/deskless" "$@"; }

pass=0 fail=0
check() {  # check NAME WANT_EXIT WANT_TEXT -- command...
  local name=$1 want_rc=$2 want=$3 out rc; shift 4
  out=$("$@" </dev/null 2>&1); rc=$?
  if [ "$rc" = "$want_rc" ] && grep -qF -- "$want" <<<"$out"; then
    pass=$((pass + 1)); echo "ok    $name"
  else
    fail=$((fail + 1)); echo "FAIL  $name (exit $rc, wanted $want_rc and '$want')"; sed 's/^/      /' <<<"$out"
  fi
}

check "bad token is refused"           1 "unable to authenticate"           -- env HCLOUD_TOKEN=bad "$work/deskless" list
check "empty list"                     0 "No deskless servers"            -- cb list
check "up won't reuse a foreign name"  1 "deskless didn't make it"        -- cb up other-box
check "down won't delete foreign box"  1 "won't delete it"                  -- cb down other-box --yes
check "bad name"                       1 "lowercase letters"                -- cb up Bad_Name
check "Hetzner's error is shown"       1 "image nope not found"             -- cb up testbox --image nope
check "price in account currency"      1 "USD 7.09 a month"                 -- env LC_ALL=de_DE.UTF-8 "$work/deskless" up testbox
check "list shows the new box"         0 "testbox"                          -- cb list
check "down needs a terminal or --yes" 1 "Pass --yes"                       -- cb down testbox
check "down deletes"                   0 "is deleted"                       -- cb down testbox --yes
check "list is empty again"            0 "No deskless servers"            -- cb list

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
