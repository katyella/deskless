# deskless

Your own always-on Claude Code server, driven from the Claude app on your phone or from
claude.ai/code. One command creates it on Hetzner, and one command deletes it.

```bash
curl -fsSLO https://raw.githubusercontent.com/katyella/deskless/main/deskless && chmod +x deskless
export HCLOUD_TOKEN=...       # Hetzner Console > your project > Security > API tokens (Read & Write)
./deskless up mybox         # create the server and set it up
./deskless down mybox       # sign it out of everything and delete it
./deskless list             # the boxes this script made
```

The box runs [Claude Code Remote Control](https://code.claude.com/docs/en/remote-control) as a
service. It dials out to Anthropic, so it needs no open ports, and it comes back on its own after
a crash or a reboot.

## What you need

- A Claude **Pro, Max, Team or Enterprise** plan. Remote Control doesn't work with API keys.
- A Hetzner Cloud account and an API token for one of its projects.
- An SSH key on your laptop (`ssh-keygen -t ed25519` if you don't have one).
- The Claude app on your phone.
- [Tailscale](https://tailscale.com) on your laptop. It's optional but recommended, and free for
  personal use.
- macOS or Linux with `curl`, `jq` and `ssh`. On Windows, use WSL.

## What it costs

`up` prints the price before it creates anything. The default CX23 (2 vCPU, 4 GB) costs $7.09 a
month with its IPv4 address on a US account; the API reports the price in your account's currency.
Hetzner bills by the hour up to that monthly cap, and only deleting the server stops the bill.
Switching it off doesn't.

## What `up` does

1. Creates the server through Hetzner's API, labelled `deskless`, with your SSH key.
2. Updates the packages, turns on automatic security updates, and adds 2 GB of swap.
3. Creates an `agent` user with no sudo and installs Claude Code for it.
4. Writes a guardrail `settings.json` and a starter `CLAUDE.md` in `~/work`.
5. Puts the box on your tailnet. Set `TAILSCALE_AUTHKEY` to skip the browser approval.
6. Asks you to sign in to Claude, and optionally GitHub.
7. Runs Remote Control once in the foreground: answer `y` twice, press space for a QR code, scan
   it, then press Ctrl-C.
8. Installs `remote-control.service`, then checks that your laptop can SSH over Tailscale. Only if it
   can does it close SSH on the public IP.

Running `up` again on the same box re-runs setup and keeps what's already there.

Options: `--type`, `--location`, `--image`, `--ssh-key`, `--no-tailscale`, and
`--permission-mode` (default `dontAsk`). See `./deskless --help`.

Already have a server? Copy the script to it and run `sudo bash deskless setup`.

## What Claude can and can't do on the box

Sessions run as `agent`, a normal user with no sudo, in `dontAsk` mode. Claude can read, edit
and run anything that user can, including network access, without asking. The deny rules block
sudo, changes to Tailscale, SSH and the Remote Control service, force-pushes, and reading
Claude's own login token.

Treat the deny rules as guard rails, not a sandbox. The real boundaries are the unprivileged
user, the firewall and Tailscale. So:

- Don't put secrets on the box that you wouldn't hand to the agent.
- A GitHub sign-in gives Claude everything your GitHub account can do. A separate machine
  account, or a fine-grained token limited to a few repos, keeps that smaller.
- Anything Claude reads, such as web pages, issues or repos, can try to steer it.

## Tearing it down

`./deskless down mybox` asks you to type the name, then:

1. Signs the box out of Claude, GitHub and Tailscale.
2. Deletes the server.
3. Cleans up your `known_hosts`.

It refuses to touch any server without the `deskless` label.

Tailscale keeps listing the box as logged out until you remove it under
[Machines](https://login.tailscale.com/admin/machines).

## When something's wrong

```bash
ssh root@<tailscale-ip>                  # printed at the end of `up`
systemctl status remote-control          # is Remote Control running?
journalctl -u remote-control -f          # its errors
runuser -l agent -c 'claude auth login' && systemctl restart remote-control   # sign in again
```

In the Tailscale admin console, turn off key expiry for the box. Otherwise it drops off your
tailnet after 180 days.

## Tests

- `bash test/api-test.sh` runs `up`, `down` and `list` against a local mock of the Hetzner API.
  Nothing real is created.
- `test/e2e.exp` drives a real `up`, answering its prompts. The links that need you are written
  to a folder; see its header.

## License

MIT. See [LICENSE](LICENSE).
