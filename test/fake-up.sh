#!/usr/bin/env bash
# Stands in for `deskless up NAME` in test/skill-test.sh: prints what a real run prints at each step
# that needs a person, in the same order, and reads the answers the way the real prompts do.
say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
name=$2
say "Creating '$name': cx23 in hel1, ubuntu-24.04"
echo "    USD 7.09 a month with its IPv4 address, billed by the hour until: ./deskless down $name"
say "Tailscale, so only your own devices can reach the box"
printf '\nTo authenticate, visit:\n\n\thttps://login.tailscale.com/a/1a2b3c4d5e\n\n'
sleep 1
say "Signing Claude Code in to your Claude account"
echo "Browse to: https://claude.ai/oauth/authorize?code=true&client_id=abc&state=xyz"
printf 'Paste code here if prompted > '
read -r code
[ ${#code} -ge 20 ] || { echo "bad code"; exit 3; }
say "GitHub (optional), so Claude can clone, push and open PRs"
printf 'Sign the box in to GitHub? [Y/n] '
read -r gh
if [ "$gh" = y ]; then
  printf '? Authenticate Git with your GitHub credentials? (Y/n) \033[6n'
  read -r _
  echo "! First copy your one-time code: ABCD-1234"
  printf 'Press Enter to open https://github.com/login/device in your browser... '
  read -r _
fi
say "First Remote Control run"
printf 'Ready? [Y/n] '
read -r _
printf 'Trust /home/agent/work? '
read -r _
printf 'Enable Remote Control? '
read -r _
trap 'echo; echo stopped' INT
echo "Continue in the app: https://claude.ai/code?environment=env_01AbCdEf"
sleep 30 & wait $!
trap - INT
say "Connecting from this computer over Tailscale"
echo "    Its Tailscale key never expires, so it stays on your tailnet."
echo "    From now on: ssh root@100.64.0.42"
