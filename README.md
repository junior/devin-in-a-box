<div align="center">

<img src="assets/brand/devin-in-a-box-primary.png" alt="Devin in a Box logo" width="240">

# Devin in a Box

**Run Devin CLI safely and non-interactively in containers and CI pipelines.**

[![Publish](https://github.com/junior/devin-in-a-box/actions/workflows/publish.yml/badge.svg)](https://github.com/junior/devin-in-a-box/actions/workflows/publish.yml)
[![GHCR](https://img.shields.io/badge/GHCR-devin--in--a--box-181717?logo=github)](https://github.com/junior/devin-in-a-box/pkgs/container/devin-in-a-box)
[![Docker Pulls](https://img.shields.io/docker/pulls/junior/devin-in-a-box?logo=docker)](https://hub.docker.com/r/junior/devin-in-a-box)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platform-linux%2Famd64%20%7C%20linux%2Farm64-2496ED?logo=docker)](https://github.com/junior/devin-in-a-box/pkgs/container/devin-in-a-box)

[Quick start](#quick-start) · [Docker Sandboxes](#docker-sandboxes) · [GitLab CI](#gitlab-ci) · [Model controls](#model-cost-controls) · [Firewall policy](FIREWALL.md)

</div>

Devin in a Box packages the official [Devin CLI](https://docs.devin.ai/cli)
for deterministic, non-interactive use in GitLab CI and other containerized
workflows. Give it a prompt, mount a workspace and credentials, and receive a
plain response that the next job can consume.

```mermaid
flowchart LR
    A[Prompt or file] --> B[Devin in a Box]
    C[Runtime credential mount] --> B
    B --> D[Devin CLI]
    D --> E[Plain-text response]
    D --> F[ATIF conversation export]
```

## Why this exists

- **CI-native:** uses Devin's `--print` mode and exits after one response.
- **Clean output:** suppresses first-run UI so stdout stays machine-readable.
- **No baked credentials:** authentication is mounted only at runtime.
- **Predictable cost:** defaults to `swe-1.6`, with an explicit model override.
- **Hardened base:** built on Docker Hardened Debian 13 (Trixie).
- **Pipeline handoff:** writes a response and optional ATIF export as artifacts.
- **Enterprise-friendly:** includes model-control and firewall guidance.

## Quick start

### 1. Authenticate once

On a trusted workstation, install Devin CLI and sign in:

```bash
devin auth login
```

The credential file is normally stored at:

```text
~/.local/share/devin/credentials.toml
```

If `XDG_DATA_HOME` is set, use
`$XDG_DATA_HOME/devin/credentials.toml` instead. Treat this file like an API
token: never commit it, copy it into an image, or expose it in job logs.

### 2. Run the published image

Choose either registry:

```bash
export DEVIN_IMAGE=ghcr.io/junior/devin-in-a-box:latest
# Or: export DEVIN_IMAGE=junior/devin-in-a-box:latest
```

Run a read-only prompt against the current repository:

```bash
docker run --rm \
  --volume "$PWD:/workspace" \
  --volume "$HOME/.local/share/devin/credentials.toml:/run/secrets/credentials.toml:ro" \
  --env DEVIN_CREDENTIALS_FILE=/run/secrets/credentials.toml \
  --env DEVIN_PERMISSION_MODE=normal \
  --env 'DEVIN_PROMPT=Review this repository and list the three highest-risk issues.' \
  "$DEVIN_IMAGE"
```

Or pipe a prompt over standard input:

```bash
printf '%s\n' 'Summarize this repository.' | docker run --rm -i \
  --volume "$PWD:/workspace" \
  --volume "$HOME/.local/share/devin/credentials.toml:/run/secrets/credentials.toml:ro" \
  --env DEVIN_CREDENTIALS_FILE=/run/secrets/credentials.toml \
  "$DEVIN_IMAGE"
```

## Inputs and outputs

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `DEVIN_CREDENTIALS_FILE` | Yes* | — | Mounted path to `credentials.toml`. *May be omitted when credentials already exist in Devin's data directory. |
| `DEVIN_PROMPT` | Yes* | — | Inline prompt. *Alternatively use `DEVIN_PROMPT_FILE` or stdin. |
| `DEVIN_PROMPT_FILE` | No | — | Path to a mounted prompt file. |
| `DEVIN_MODEL` | No | `swe-1.6` | Model passed explicitly to Devin CLI. |
| `DEVIN_PERMISSION_MODE` | No | Devin default | `normal`, `auto`, `accept-edits`, `smart`, `dangerous`, `yolo`, or `bypass`. |
| `DEVIN_OUTPUT_FILE` | No | stdout | Also write the final response to this path. |
| `DEVIN_EXPORT_FILE` | No | — | Write the conversation in ATIF format after each turn. |

Input precedence is `DEVIN_PROMPT_FILE`, then `DEVIN_PROMPT`, then stdin.

## Docker Sandboxes

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) ships a built-in
[`devin` agent](https://docs.docker.com/ai/sandboxes/agents/devin/) as of
`sbx` 0.42, so no custom image, agent kit, or launcher script is needed
anymore. The built-in agent provides the template image, the credential
capture and injection, the Devin runtime allowlist, and the MCP gateway
registration. This repository adds an optional mixin kit with the defaults
this project cares about.

### Run Devin in a sandbox

```bash
sbx run devin ~/src/your-repo
```

On the first run Devin asks you to sign in inside the sandbox: open the printed
`app.devin.ai` link, then paste the code back. Docker Sandboxes captures the
resulting credential on the host as the `devin` service secret and provisions
every later sandbox with it automatically. Re-attach later with
`sbx run --name devin-your-repo`.

If this machine already has a `credentials.toml`, seed the secret instead of
signing in interactively:

```bash
sed -nE 's/^windsurf_api_key = "([^"]+)"/\1/p' ~/.local/share/devin/credentials.toml | sbx secret set devin
```

### One-shot prompts

Create the sandbox without attaching, then run prompts with `sbx exec`:

```bash
sbx create --name devin-your-repo devin ~/src/your-repo
```

```bash
sbx exec devin-your-repo -- devin --respect-workspace-trust=false --print -- 'Summarize this repository.'
```

The built-in agent passes `--respect-workspace-trust=false` in its own
interactive entrypoint; `sbx exec` bypasses the entrypoint, so the flag is
repeated here. With the mixin below it is not needed.

### Optional mixin: project defaults

`sandbox-kit/` is a mixin that layers this project's defaults on the built-in
agent:

- `DEVIN_MODEL=swe-1.6` for predictable cost (override with
  `--env DEVIN_MODEL=your-model`);
- the enterprise tenant hosts `*.enterprise.windsurf.com` and
  `*.devinenterprise.com` in the allowlist, to pair with
  `--env WINDSURF_API_SERVER_URL=https://your-tenant`;
- a Devin config that skips the first-run wizard and the workspace-trust
  prompt, disables commit attribution, and keeps Docker's `auto_update=false`.

```bash
sbx run --kit ./sandbox-kit devin ~/src/your-repo
```

With the mixin, one-shot prompts need no flags:

```bash
sbx exec devin-your-repo -- devin --print -- 'Summarize this repository.'
```

The mixin only takes effect when the sandbox is created. Validate it with
`sbx kit validate ./sandbox-kit`.

### How the credential is handled

Devin CLI's wire protocol embeds the API key inside each request body, so the
sandbox proxy cannot keep the key on the host and inject it into headers the
way it does for other agents. Docker's agent instead captures the token during
the in-sandbox login, stores it on the host, and renders it into
`~/.local/share/devin/credentials.toml` inside each new sandbox. The
credential therefore resides in the sandbox filesystem, readable by Devin and
by any process running as `agent` or root in that microVM. The sandbox network
policy is what confines it: only the Devin endpoints in the built-in allowlist
(plus the Ubuntu package mirrors and `download.docker.com`) are reachable.
Every additional host you allow is another possible destination for the
credential, so keep task-specific egress narrow, prefer short-lived
credentials, and remove sandboxes that no longer need access.

### Make the allowlist enforceable

A kit can only add allow rules on top of the machine's global policy. Choose
default-deny when Docker Sandboxes asks for the initial global policy, or
initialize a new installation explicitly:

```bash
sbx policy init deny-all
```

`sbx policy init` is a one-time command; to replace an existing allow-all or
balanced policy, run `sbx policy reset` first. Resetting is machine-wide and
stops running sandboxes, so review the impact before confirming. Verify a
sandbox before trusting it with credentials, and audit decisions afterwards:

```bash
sbx policy check network --sandbox devin-your-repo example.com
```

```bash
sbx policy log devin-your-repo
```

Blocked hosts appear as "No matching allow rule (default deny)". Add
task-specific destinations per sandbox with
`sbx policy allow network --sandbox <name> <host>` rather than opening
unrestricted egress.

### MCP gateway

The built-in agent registers the sandbox MCP gateway in Devin's user scope
(`devin mcp list` shows `mcp-gateway`), so servers you manage with `sbx mcp`
are reachable from inside the sandbox. Attach a registration from the host
with `sbx mcp load <server> --sandbox devin-your-repo`, or preload a fixed set
at creation with `sbx create --static-mcp notion,linear ...`. Enterprise
tenants that enforce an MCP-server allowlist must approve the gateway URL
before Devin will use it.

### Retired custom sandbox image

Earlier releases published a custom sandbox agent image under the `sandbox`
and `sandbox-0.2.x` tags on GHCR and Docker Hub together with a full agent kit
and a launcher script. Those tags remain available but are frozen at 0.2.1 and
no longer built; use the built-in agent above instead.

## GitLab CI

The included [.gitlab-ci.yml](.gitlab-ci.yml) demonstrates the full flow:

1. Build the image from Docker Hardened Images.
2. Run a prompt against the checked-out repository.
3. Save `devin-output.txt` and `devin-conversation.json` as artifacts.
4. Download and consume those artifacts in the next job.

Configure these GitLab CI/CD variables:

| Variable | Type | Protection | Purpose |
| --- | --- | --- | --- |
| `DEVIN_CREDENTIALS_FILE` | File | Protected; masked if supported | Complete Devin `credentials.toml`. |
| `DHI_USERNAME` | Variable | Protected and masked | Docker ID permitted to pull from `dhi.io`. |
| `DHI_PASSWORD` | Variable | Protected and masked | Scoped Docker access token. |
| `DEVIN_PROMPT` | Variable | As appropriate | Prompt for the job. |
| `DEVIN_MODEL` | Variable | As appropriate | Optional model override. |

The sample uses Docker-in-Docker, so the GitLab runner must permit privileged
services. In production, consider building and scanning the image separately,
publishing it to an approved internal registry, and letting execution jobs pull
that immutable image.

## Model cost controls

The image defaults to `swe-1.6`, but `DEVIN_MODEL` makes planned migrations
possible when your Enterprise agreement changes. The environment variable is
operational configuration—not a security boundary.

For actual enforcement, use **Settings → Enterprise → Windsurf → Devin CLI
settings** and:

1. allowlist only the model included in your agreement;
2. set that same model as the team default; and
3. keep `DEVIN_MODEL` aligned with the allowlist.

The allowlist is enforced server-side. A default alone does not prevent users
from switching to another allowed model. See [Devin model
documentation](https://docs.devin.ai/cli/models) and [Enterprise Team
Settings](https://docs.devin.ai/cli/enterprise/team-settings).

## Permission modes

Start with `normal` for analysis. `accept-edits` automatically approves
workspace edits. Fully unattended commands may require `dangerous`, `yolo`, or
`bypass`; these modes approve all actions and should run only in isolated,
ephemeral runners with narrowly scoped credentials and no production secrets.

The container can access everything you mount and every environment variable
you pass. Keep mounts narrow and inject only the secrets the job truly needs.

## Build from source

The default base is `dhi.io/debian-base:trixie-dev`, which requires Docker
Hardened Images access:

```bash
docker login dhi.io
docker build --tag devin-in-a-box:local .
```

To use an approved internal mirror:

```bash
docker build \
  --build-arg BASE_IMAGE=registry.example.com/approved/debian-base:trixie-dev \
  --tag devin-in-a-box:local .
```

The Dockerfile uses Devin's latest-version installer. For a controlled
production rollout, mirror and checksum an approved installer/binary version in
your artifact registry.

## Network policy

See [FIREWALL.md](FIREWALL.md) for the build-time, runtime, enterprise, and
task-dependent outbound destinations.

## Publishing

The GitHub Actions workflow publishes multi-platform images to:

- `ghcr.io/junior/devin-in-a-box`
- `docker.io/junior/devin-in-a-box`

Tagged releases such as `v0.1.0` produce semantic-version tags and provenance.
Repository maintainers must configure `DHI_USERNAME`, `DHI_PASSWORD`,
`DOCKERHUB_USERNAME`, and `DOCKERHUB_TOKEN` as GitHub Actions secrets.

## Security

Read [SECURITY.md](SECURITY.md) before reporting a vulnerability. Never attach
Devin credentials, CI variables, or private repository contents to a public
issue.

## License

Project-authored files are released under the [MIT License](LICENSE). The
container includes third-party software under its respective licenses; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Official references

- [Devin CLI quickstart](https://docs.devin.ai/cli)
- [Commands and flags](https://docs.devin.ai/cli/reference/commands)
- [Devin authentication](https://docs.devin.ai/cli/enterprise/devin-auth)
- [Docker Hardened Debian Base](https://hub.docker.com/hardened-images/catalog/dhi/debian-base)
- [Docker Hardened Image build guidance](https://docs.docker.com/dhi/how-to/build/)
