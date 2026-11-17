# docker-github-runner-linux

A lean self-hosted [GitHub Actions runner](https://github.com/actions/runner) image for Linux
(amd64, arm64). It runs typical `ubuntu-latest` jobs without changes to the workflow:
checkout, `actions/setup-*`, Go/C builds with cgo (`go test -race`), shell scripts with
`gh`, `jq` and `yq`, uploads and releases.

```
ghcr.io/spali/docker-github-runner-linux:latest
```

## What is in the image

Based on the official [`ghcr.io/actions/actions-runner`](https://github.com/actions/runner/pkgs/container/actions-runner)
image (Ubuntu 24.04), plus:

| Tool | Why |
|---|---|
| `git`, `curl`, `jq`, `unzip`, `sudo`, `docker` CLI | from the base image |
| `gh` | GitHub CLI for scripts |
| `yq` (mikefarah) | YAML in scripts |
| `build-essential`, `pkg-config` | cgo, `go test -race`, native builds |
| `zip`, `xz-utils`, `zstd`, `file` | archives and caches of the actions |
| `shellcheck`, `python3` | common checks and scripts |

Not included, as on purpose lean: language toolchains. `actions/setup-go`, `setup-node`,
`setup-python` and others download them into the tool cache `/opt/hostedtoolcache`;
mount a volume there to download each version only once. Jobs can install more with
`sudo apt-get install`.

## Run it

1. Create a fine-grained personal access token for the runner's repositories with
   **Administration: read and write** (organization runner: **Self-hosted runners: read
   and write**).
2. Copy [`compose.yml`](compose.yml) and [`.env.example`](.env.example) (as `.env`), set
   `ACCESS_TOKEN` and the `RUNNER_URL` of each service.
3. `docker compose up -d`
4. In the workflow: `runs-on: [self-hosted, linux]`.

Repositories of a user account need one runner per repository; an organization can
register one runner for all its repositories with `RUNNER_URL: https://github.com/ORG`.

| Variable | Default | Meaning |
|---|---|---|
| `RUNNER_URL` | required | `https://github.com/OWNER/REPO` or `https://github.com/ORG` |
| `ACCESS_TOKEN` | | PAT, fetches a registration token on every start |
| `RUNNER_TOKEN` | | instead of `ACCESS_TOKEN`: registration token from the settings page (valid 1 h, only with `EPHEMERAL=false`) |
| `RUNNER_NAME` | container hostname | name shown on GitHub |
| `RUNNER_LABELS` | | extra labels, comma separated; `self-hosted`, `Linux`, `X64`/`ARM64` are always set |
| `RUNNER_GROUP` | | runner group (organizations) |
| `EPHEMERAL` | `true` | one job per registration: the container restarts with a clean workspace after every job |

The runner does not update itself: pull a newer image tag. GitHub stops sending jobs to
runners that are too old, so keep the image current (`latest`, or a pinned version with
renovate).

## Docker in jobs

Jobs with `container:`, `services:` or `docker build` need a Docker daemon. Mount the
host's socket (see `compose.yml`). The jobs then control the host's Docker, which equals
root on the host.

## Security

- Use self-hosted runners only for repositories whose workflows you trust. For a
  public repository, set *Settings → Actions → General → Require approval for all
  external contributors*, otherwise a pull request from a fork runs its code on your
  machine.
- Jobs run with `sudo` inside the container; the access token is not in their
  environment, but they could read it. Give the token only the permission above.
- `EPHEMERAL=true` (the default) gives every job a clean workspace; the tool cache volume
  is shared between jobs.

## Releases

Versions follow the shared release flow of [spali/.github](https://github.com/spali/.github).

| Image tag | Built from |
|---|---|
| `X.Y.Z`, `X.Y`, `X`, `latest` | release |
| `X.Y.Z-next`, `next` | every push to `main` |
| `X.Y.Z-pr.N` | dev build of a pull request (manual workflow run on its branch) |

Every image has a build provenance attestation: `gh attestation verify
oci://ghcr.io/spali/docker-github-runner-linux:latest --owner spali`. The release lists
the image with its digest (`image.txt`) and a `compose.yml` for that version.

## Test locally

```sh
docker build -t runner:test .
docker run --rm --entrypoint bash -v "$PWD/test:/test:ro" runner:test /test/smoke.sh
```

## License

[MIT](LICENSE)
