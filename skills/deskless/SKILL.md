---
name: deskless
description: Create, list or delete an always-on Claude Code server on Hetzner that the user drives from the Claude mobile app or claude.ai/code (Remote Control, reachable only over Tailscale). Use when the user wants a cloud box or remote machine for Claude Code, wants to see the ones they have, or wants one torn down.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/deskless list)
---

# deskless

[deskless](https://github.com/katyella/deskless) creates a Hetzner server through Hetzner's API. It installs Claude Code under an unprivileged `agent` user and runs Remote Control as a service. It puts the box on the user's tailnet and closes public SSH once this computer can reach the box over Tailscale. `down` signs the box out and deletes it.

A few steps need the person: approving the box on Tailscale, the Claude sign-in, and an optional GitHub sign-in. `drive.exp` runs `deskless up` and answers the script's own prompts. It hands each step that needs the person to you as a file, and you relay it.

## Before anything

1. **The script.** Use `${CLAUDE_SKILL_DIR}/deskless`. If it's missing, fetch it:
   `curl -fsSL -o "${CLAUDE_SKILL_DIR}/deskless" https://raw.githubusercontent.com/katyella/deskless/v1/deskless && chmod +x "${CLAUDE_SKILL_DIR}/deskless"`
2. **The Hetzner token.** Use `HCLOUD_TOKEN` if it's set. Otherwise ask the user for a Read & Write API token (Hetzner Console > their project > Security > API tokens). Save it to a private file outside any repository (`umask 077`), and pass it to each command as `HCLOUD_TOKEN="$(cat FILE)"`. Never print it. A token pasted into chat stays in the transcript, so suggest they regenerate it when they're done.
3. **Tools on this computer.** `expect` (built into macOS; on Linux, `sudo apt install expect`), `jq`, `curl`, `ssh`, and an SSH key (`ls ~/.ssh/id_*.pub`; if there's none, ask before running `ssh-keygen -t ed25519`). Check `tailscale ip -4` too. If this computer isn't on Tailscale, the box keeps public SSH open; say so.
4. **Ask the user**:
   - **A name:** lowercase letters, digits and dashes. It becomes the hostname and the name in the Claude app.
   - **GitHub:** signing in gives Claude on the box everything their GitHub account can do.
   - **The cost:** a CX23 runs about $7 a month, billed by the hour until it's deleted. `up` prints the exact price.

## Create a box

Make a private working folder, then start the driver in the background:

```bash
DIR=$(mktemp -d) && chmod 700 "$DIR"
HCLOUD_TOKEN="$(cat TOKEN_FILE)" GITHUB=1 expect -f "${CLAUDE_SKILL_DIR}/drive.exp" NAME "$DIR"
```

Leave out `GITHUB=1` to skip GitHub. Any `up` options go after `"$DIR"`: `--type`, `--location`, `--image`, `--no-tailscale`, `--permission-mode`. If the user set `TAILSCALE_AUTHKEY`, the box joins without a Tailscale approval.

Wait for files to appear in `$DIR` with a background loop, not a foreground sleep. Relay each one as soon as it shows up:

| File | What to tell the user |
| --- | --- |
| `ts_url` | Open this link and approve the box on Tailscale. |
| `claude_url` | Open this link, approve, and paste back the code the page shows. Write their reply to `$DIR/claude_code` (with `umask 077`). The code works once. |
| `gh_code` | Enter this code at https://github.com/login/device. It expires after 15 minutes. |
| `exit` | Finished. `0` means success; anything else, read the end of `$DIR/up.log`. |

On success, tell the user:
- In the Claude app, go to Code and pick NAME. The same box is at claude.ai/code.
- SSH works with `ssh root@<Tailscale IP>`, printed in the last lines of `$DIR/up.log`.
- In the Tailscale admin console, turn off key expiry for the box, or it drops off the tailnet after 180 days.

Then delete `$DIR`, because it holds the sign-in link and code.

Running `up` again on an existing name re-runs setup and keeps what's already there, so it's the fix for a run that stopped halfway.

## List boxes

```bash
HCLOUD_TOKEN="$(cat TOKEN_FILE)" "${CLAUDE_SKILL_DIR}/deskless" list
```

## Delete a box

This deletes the server and everything on it. Name the box and get the user's explicit yes first, then:

```bash
HCLOUD_TOKEN="$(cat TOKEN_FILE)" "${CLAUDE_SKILL_DIR}/deskless" down NAME --yes
```

It signs the box out of Claude, GitHub and Tailscale, deletes it, and Hetzner stops billing. The script refuses servers it didn't create. Afterwards, tell the user to remove the box, now listed as logged out, at https://login.tailscale.com/admin/machines.

## When something goes wrong

- `ssh root@<Tailscale IP> journalctl -u remote-control -n 50` shows why Remote Control isn't running.
- A warning about the plan means the Claude login can't use Remote Control. It needs a Pro, Max, Team or Enterprise plan; API keys don't work.
- Hetzner's own error messages come through as they are, for example a server type that isn't sold in that location. Pick another `--type` or `--location`.
