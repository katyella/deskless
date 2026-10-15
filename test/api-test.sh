#!/usr/bin/env bash
# Runs deskless's laptop commands (up, down, list, session) against a local mock of the Hetzner and Tailscale
# APIs. Nothing real is created. Stand-ins for ssh and tailscale go first on PATH: no box ever answers
# SSH, and this "laptop" is on a tailnet where testbox is 100.64.0.42.
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
mkdir "$work/bin"
printf '#!/bin/sh\nexit 255\n' > "$work/bin/ssh"
printf '#!/bin/sh\ncase "$*" in "ip -4") echo 100.64.0.1 ;; "ip -4 testbox") echo 100.64.0.42 ;; *) exit 1 ;; esac\n' > "$work/bin/tailscale"
chmod +x "$work/bin/ssh" "$work/bin/tailscale"
export PATH="$work/bin:$PATH" DESKLESS_CONFIG="$work/config"
export HCLOUD_API=http://127.0.0.1:$port/v1 HCLOUD_TOKEN=good TAILSCALE_API=http://127.0.0.1:$port/api/v2
devices() { curl -s -H 'Authorization: Bearer tsgood' "$TAILSCALE_API/tailnet/-/devices" | jq -r '"ids: \([.devices[].id] | join(" "))."'; }
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
check "empty list"                     0 "No deskless servers"              -- cb list
check "up won't reuse a foreign name"  1 "deskless didn't make it"          -- cb up other-box
check "down won't delete foreign box"  1 "won't delete it"                  -- cb down other-box --yes
check "bad name"                       1 "lowercase letters"                -- cb up Bad_Name
check "Hetzner's error is shown"       1 "image nope not found"             -- cb up testbox --image nope
check "price in account currency"      1 "USD 7.09 a month"                 -- env LC_ALL=de_DE.UTF-8 "$work/deskless" up testbox
check "list shows the new box"         0 "testbox"                          -- cb list
check "down needs a terminal or --yes" 1 "Pass --yes"                       -- cb down testbox
check "down, bad Tailscale key: note"  0 "remove it:"                       -- env TAILSCALE_API_KEY=bad "$work/deskless" down testbox --yes
check "no Tailscale key: says so"      0 "TAILSCALE_API_KEY"                -- sh -c "'$work/deskless' up testbox; '$work/deskless' down testbox --yes"
check "Tailscale untouched so far"     0 "ids: 501 502 503."                -- devices
cb up testbox >/dev/null 2>&1
check "down removes it from Tailscale" 0 "Removed it from your tailnet"     -- env TAILSCALE_API_KEY=tsgood "$work/deskless" down testbox --yes
check "only that device is gone"       0 "ids: 502 503."                    -- devices
check "list is empty again"            0 "No deskless servers"              -- cb list

# session: a stand-in ssh that answers like a reachable box and shows what start-session would get.
mkdir "$work/okbin"
cat > "$work/okbin/ssh" <<'EOF'
#!/usr/bin/env bash
for a; do last=$a; done
[ "$last" != true ] || exit 0
eval "set -- $last"
echo "box got: title=[$5] message=[$(printf '%s' "$6" | base64 -d)]"
EOF
chmod +x "$work/okbin/ssh"
check "session checks the title"       1 "Keep the title"                   -- cb session testbox 'a/b'
check "session needs a message"        1 "needs a first message"            -- cb session testbox hello
check "session, box unreachable"       1 "Can't reach 'testbox'"            -- sh -c "echo hi | '$work/deskless' session testbox hello"
check "session sends title and message" 0 "box got: title=[kanban board] message=[Build it, it's \"done\" \$5]" \
  -- env PATH="$work/okbin:$PATH" sh -c "printf '%s' 'Build it, it'\\''s \"done\" \$5' | '$work/deskless' session testbox 'kanban board'"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
