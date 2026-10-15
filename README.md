# deskless

Your own always-on Claude Code server, driven from the Claude app on your phone or from
claude.ai/code. One command creates it on Hetzner, and one command deletes it.

**The easy way:** let Claude Code walk you through it. Install the plugin, then start a new
Claude Code session and ask for a box:

```bash
claude plugin install deskless --marketplace katyella/deskless
claude          # then say: "set me up a deskless box"
```

It checks what you have and helps with what's missing, one step at a time. It creates the box
and hands you each sign-in. Later, ask it to list your boxes or delete one, or to start work on
a box: it starts a session there that you watch and answer in the Claude app. More in
[Let Claude Code do it](#let-claude-code-do-it).

**The script on its own:**

```bash
curl -fsSLO https://raw.githubusercontent.com/katyella/deskless/v1.2/deskless && chmod +x deskless
./deskless up mybox         # create the server and set it up; asks for your Hetzner token once
./deskless down mybox       # sign it out of everything and delete it
./deskless list             # the boxes this script made
echo 'Build a small to-do web app' | ./deskless session mybox 'todo app'
                            # start a session on the box; it shows up in the Claude app
```

The box runs [Claude Code Remote Control](https://code.claude.com/docs/en/remote-control) as a
service. It dials out to Anthropic, so it needs no open ports, and it comes back on its own after
a crash or a reboot.

## What you need

- A Claude **Pro, Max, Team or Enterprise** plan. Remote Control doesn't work with API keys.
- A Hetzner Cloud account and an API token for one of its projects (Hetzner Console > your
  project > Security > API tokens, Read & Write). The script asks for it and offers to remember
  it in `~/.config/deskless/hetzner-token`, or you can set `HCLOUD_TOKEN`.
- An SSH key on your laptop (`ssh-keygen -t ed25519` if you don't have one).
- The Claude app on your phone.
- [Tailscale](https://tailscale.com) on your laptop. It's optional but recommended, and free for
  personal use. Your phone doesn't need it.
- Optionally, a Tailscale [API access token](https://login.tailscale.com/admin/settings/keys) in
  `TAILSCALE_API_KEY` or `~/.config/deskless/tailscale-api-key`. With it, the box joins your
  tailnet without a browser approval, its key never expires, and `down` removes it from the tailnet.
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
5. Puts the box on your tailnet. With a Tailscale API token, or an auth key in `TAILSCALE_AUTHKEY`,
   there's no browser approval.
6. Asks you to sign in to Claude, and optionally GitHub. When gh asks to authenticate Git, answer Y.
7. Runs Remote Control once in the foreground: answer `y` twice, press space for a QR code, scan
   it, then press Ctrl-C.
8. Installs `remote-control.service`, then checks that your laptop can SSH over Tailscale. Only if it
   can does it close SSH on the public IP.
9. With a Tailscale API token, turns off the box's key expiry so it stays on your tailnet.

Running `up` again on the same box re-runs setup and keeps what's already there.

Options: `--type`, `--location`, `--image`, `--ssh-key`, `--no-tailscale`, and
`--permission-mode` (default `dontAsk`). See `./deskless --help`.

Already have a server? Copy the script to it and run `sudo bash deskless setup`.

## Let Claude Code do it

This repo is a Claude Code plugin with one skill. It suits someone who has never set up a
server. Install it once:

```bash
claude plugin install deskless --marketplace katyella/deskless
```

or, inside a session, `/plugin marketplace add katyella/deskless`, then `/plugin install deskless@deskless`.
Start a new session and ask in your own words, such as "I want Claude Code on my phone" or
"set me up a deskless box called mybox". You can also type `/deskless:deskless`. The skill:

- checks your computer and lists what's ready and what isn't;
- walks you through anything missing, such as a Hetzner account and token or Tailscale;
- reads tokens from your clipboard, so you never paste them into the chat;
- creates the box after you say yes, posts progress, and gives you each sign-in link or code
  when it's your turn;
- lists your boxes, and deletes one after you confirm.

The plugin's hook lets the skill's read-only steps (`check`, `wait`, `list` and so on) run
without a permission prompt. Creating and deleting a box, and starting a session on it, always ask. The hook and the helper
behind it are in `hooks/` and `skills/deskless/`.

The skill without the plugin, for Claude Code or another agent that reads `SKILL.md`:

```bash
mkdir -p ~/.claude/skills/deskless && cd ~/.claude/skills/deskless && for f in SKILL.md helper drive.exp; do
  curl -fsSLO "https://raw.githubusercontent.com/katyella/deskless/v1.2/skills/deskless/$f"; done &&
  curl -fsSLO https://raw.githubusercontent.com/katyella/deskless/v1.2/deskless
```

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

With a Tailscale API token, `down` also removes the box from your tailnet. That's only the
device the box reports as itself, or the one with its name and Tailscale address, never another.
Without a token, Tailscale keeps listing the box as logged out until you remove it under
[Machines](https://login.tailscale.com/admin/machines).

## When something's wrong

```bash
ssh root@<tailscale-ip>                  # printed at the end of `up`
systemctl status remote-control          # is Remote Control running?
journalctl -u remote-control -f          # its errors
runuser -l agent -c 'claude auth login' && systemctl restart remote-control   # sign in again
```

Without a Tailscale API token, turn off key expiry for the box in the Tailscale admin console.
Otherwise it drops off your tailnet after 180 days.

## Tests

- `bash test/api-test.sh` runs `up`, `down` and `list` against a local mock of the Hetzner and
  Tailscale APIs. Nothing real is created.
- `bash test/skill-test.sh` runs the skill's helper through a whole `up`, with a stand-in for
  the script, and checks every event the agent relays.
- `bash test/hook-test.sh` checks which commands the plugin's hook approves on its own.
- `skills/deskless/drive.exp` drives a real `up`, answering its prompts. The links and codes that
  need you are written to a folder; see its header. `GITHUB=1` includes the GitHub sign-in.

## License

MIT. See [LICENSE](LICENSE).
