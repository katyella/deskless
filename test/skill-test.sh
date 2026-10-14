#!/usr/bin/env bash
# Runs the skill's helper through a whole `up` with test/fake-up.sh in place of deskless: the
# events an agent relays, in order, and the answers that reach the prompts.
#   bash test/skill-test.sh
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
helper=$here/../skills/deskless/helper
export TMPDIR=$(mktemp -d) DESKLESS=$here/fake-up.sh
trap 'rm -rf "$TMPDIR"' EXIT
command -v expect >/dev/null || { echo "skipped: needs expect"; exit 0; }

bash "$helper" up demo --github >/dev/null 2>&1 &
events=''
for i in $(seq 1 30); do
  out=$(bash "$helper" wait demo 60)
  events+=$out$'\n'
  case $out in *claude-sign-in:*) bash "$helper" code demo test-code-0123456789abcdef >/dev/null ;; esac
  case $out in *finished:*|*stopped:*) break ;; esac
done
wait

want='step: Creating '"'"'demo'"'"': cx23 in hel1, ubuntu-24.04
price: USD 7.09 a month with its IPv4 address, billed by the hour until: ./deskless down demo
step: Tailscale, so only your own devices can reach the box
approve-tailscale: https://login.tailscale.com/a/1a2b3c4d5e
step: Signing Claude Code in to your Claude account
claude-sign-in: https://claude.ai/oauth/authorize?code=true&client_id=abc&state=xyz
claude-code-received
step: GitHub (optional), so Claude can clone, push and open PRs
github-code: ABCD-1234
step: First Remote Control run
connected: https://claude.ai/code?environment=env_01AbCdEf
step: Connecting from this computer over Tailscale
tailscale: Its Tailscale key never expires, so it stays on your tailnet.
ssh: ssh root@100.64.0.42
finished: ok'
got=$(grep -v '^still working$' <<<"$events" | grep -v '^$')
# Events can arrive in one batch or several; their order within the run is what matters.
if [ "$(sort <<<"$got")" = "$(sort <<<"$want")" ]; then
  echo "ok    the helper relays every step of a run, and the answers get through"
else
  echo "FAIL  events differ:"; diff <(echo "$want") <(echo "$got") | sed 's/^/      /'; exit 1
fi
