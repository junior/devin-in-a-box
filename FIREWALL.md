# Outbound firewall policy for Devin CLI CI

Allow DNS resolution and outbound TCP 443. The exact policy should be tested
with your Devin tenant and proxy because enterprise hosts, MCP servers, source
control, and task-selected package registries are organization-specific.

## Required to build this image

| Destination | Port/protocol | Purpose |
| --- | --- | --- |
| `dhi.io` | TCP 443 / HTTPS | Pull Docker Hardened Images and DHI-hardened Debian packages; Docker documents that builders must authenticate to this registry. |
| `deb.debian.org` | TCP 443 / HTTPS | Debian Trixie package indexes and packages not supplied by DHI. The Dockerfile rewrites the base image's default HTTP sources to HTTPS. |
| `cli.devin.ai` | TCP 443 / HTTPS | Download the official Devin CLI installer. |
| `static.devin.ai` | TCP 443 / HTTPS | Installer manifest, checksummed CLI bundle, and CLI updates. The current installer explicitly fetches these resources from this host. |

Depending on how DHI authentication is configured, your builder may also need
Docker's authentication endpoints. If you mirror the base image internally,
replace `dhi.io` and any Docker authentication endpoints with your internal
registry endpoints.

## Required when Devin CLI runs

| Destination | Port/protocol | Purpose |
| --- | --- | --- |
| `api.devin.ai` | TCP 443 / HTTPS and WSS | Cognition API backend and live WebSocket traffic. |
| `app.devin.ai` | TCP 443 / HTTPS | Cognition web application, authentication/session URLs, and resource downloads. |
| `static.devin.ai` | TCP 443 / HTTPS | CLI update metadata and binaries. |
| `server.codeium.com` | TCP 443 / HTTPS and WSS | Model/backend traffic used by Cognition clients. This host is present in the current CLI and is covered by Devin's published `*.codeium.com` backend allowlist. |
| `unleash.codeium.com` | TCP 443 / HTTPS | Feature configuration used by Cognition clients; covered by the same published `*.codeium.com` allowlist. |

For a dedicated enterprise deployment, use the tenant equivalents instead:

- `<tenant>.devinenterprise.com`, `cli.devinenterprise.com`, and
  `static.devinenterprise.com` on TCP 443; or
- the custom `enterprise_host` configured in `/etc/devin/system.json`.

If wildcard policies are allowed, Devin's published guidance says
`*.devin.ai` covers `app.devin.ai` and `api.devin.ai`. A host-specific policy
is tighter. WebSocket upgrade requests must be allowed through the proxy for
`api.devin.ai`.

## Only when those features are used

These are not universal Devin endpoints. Add only the destinations required by
the prompt and repository:

- your GitLab instance and Git/SSH host (`443` for HTTPS, optionally `22` for
  SSH);
- language and OS package registries used by builds/tests, preferably internal
  mirrors;
- configured MCP server URLs and OAuth providers;
- websites the prompt explicitly asks Devin to access;
- broader legacy Windsurf/Codeium domains if your organization still uses that
  login method: `*.windsurf.com`, `*.codeiumdata.com`, `*.googleapis.com`, and
  `apis.google.com`. (`*.codeium.com` is already represented by the two stable
  runtime hosts above; use the wildcard if host-specific rules are impractical.)

The provided GitLab job passes only the Devin credentials file and selected
Devin variables into the nested container. It does not automatically forward
all GitLab CI secrets.

## Build-time versus runtime policy

For the narrowest policy, build and scan the image in a controlled image-build
project, publish it to your internal registry, and let the execution job pull
only that approved image. The execution job then needs only:

1. the internal container registry;
2. the Devin runtime hosts above; and
3. explicitly approved task-dependent destinations.

## Sources

- [Devin published domain allowlist](https://docs.devin.ai/desktop/troubleshooting/windsurf-common-issues#what-domains-should-i-allowlist-for-network-filters/firewalls-vpns-or-proxies)
- [Devin CLI system and proxy configuration](https://docs.devin.ai/cli/enterprise/system-config)
- [Devin CLI installer](https://cli.devin.ai/install.sh)
- [Docker Hardened Debian Base catalog](https://hub.docker.com/hardened-images/catalog/dhi/debian-base)
- [Docker DHI build documentation](https://docs.docker.com/dhi/how-to/build/)

The current installed CLI binary was also inspected locally as a cross-check.
It contains the stable hosts listed above plus beta, legacy, font, and example
hosts. Embedded strings alone do not prove that a destination is contacted, so
beta/example hosts were not placed in the required allowlist. Validate the
final policy with firewall/proxy logs from an authenticated test pipeline.
