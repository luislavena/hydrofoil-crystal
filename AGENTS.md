# Instructions for AI agents

This document provides guidance for AI agents working with this repository.

## Repository overview

Hydrofoil Crystal is an opinionated, Alpine-based development container for the
Crystal programming language. It provides Docker images with Crystal compiler,
Shards package manager, and essential development tools.

### Directory structure

```
.
├── docker/           # Dockerfiles for each Crystal version
│   ├── 1.17/
│   ├── 1.18/
│   ├── 1.19/
│   └── ...
├── .github/
│   ├── versions.json # Version matrix for CI builds
│   └── workflows/
│       └── ci.yml    # GitHub Actions workflow
├── examples/         # Usage examples
├── goss.yaml         # Container validation tests
└── Makefile          # Local build commands
```

## Adding a new Crystal version

When adding support for a new Crystal version, follow these steps:

### 1. Calculate SHA256 checksums

Use curl to download and calculate checksums for Crystal and Shards:

```bash
# Crystal source tarball
curl -L https://github.com/crystal-lang/crystal/archive/refs/tags/VERSION.tar.gz | sha256sum -

# Shards source tarball
curl -L https://github.com/crystal-lang/shards/archive/refs/tags/vVERSION.tar.gz | sha256sum -
```

### 2. Create the Dockerfile

Create a new directory under `docker/` with the major.minor version (e.g.,
`docker/1.19/`) and copy the Dockerfile from the previous version as a base.

Update the following values in the new Dockerfile:

- `CRYSTAL_VERSION` and `CRYSTAL_SHA256`
- `SHARDS_VERSION` and `SHARDS_SHA256`
- `ALPINE_VERSION` if a newer stable release is available

Key components in the Dockerfile:

- **stage0**: Cross-compiles Crystal and Shards using Alpine's packaged Crystal
- **stage1**: Links the compiled objects on the target platform
- **stage2**: Prepares binaries and source code
- **stage3**: Final image with development tools (fixuid, Overmind, watchexec)

### 3. Update versions.json

Add an entry to `.github/versions.json`:

```json
{
  "1.19": {
    "crystal_full": "1.19.0"
  }
}
```

The key is the major.minor version, and `crystal_full` is the complete version
string.

### 4. Test the build locally

Use the Makefile to build and test:

```bash
# Build the image
make build VERSION=1.19

# Run container tests with goss
make test VERSION=1.19

# Open an interactive shell
make console VERSION=1.19
```

### 5. Verify the build output

The build should show successful compilation and smoke tests:

```
Crystal X.Y.Z (YYYY-MM-DD)
LLVM: XX.X.X
Default target: <arch>-alpine-linux-musl

Shards X.Y.Z (YYYY-MM-DD)
```

## Build considerations

### Multi-architecture support

The Dockerfiles support both `linux/amd64` and `linux/arm64` through
cross-compilation. The `TARGETARCH` build argument is used to compile for the
target platform.

### Static linking

Crystal and Shards are compiled with `static=1` to produce statically linked
binaries that work with Alpine's musl libc.

### LLVM version

The LLVM version is determined by Alpine's package repository. Check the
Dockerfile for `llvm*-dev` packages to see which version is used.

### Alpine version

Use a stable Alpine release. The version is set via `ALPINE_VERSION` ARG at the
top of the Dockerfile and is used consistently across all build stages.

## Commit guidelines

Follow these rules for commit messages:

1. Separate subject from body with a blank line
2. Limit subject line to 50 characters
3. Capitalize the subject line
4. Do not end the subject line with a period
5. Use imperative mood in the subject line
6. Wrap body at 72 characters
7. Use the body to explain what and why, not how

Example commit for a new version:

```
Builds Crystal 1.19.0

Introduces support for the latest Crystal release to keep the
container images up to date with upstream development.

Version details:
- Crystal 1.19.0
- Shards 0.20.0
- Alpine 3.23.2
- LLVM 21.1.2
```

For patch-level updates (e.g., 1.19.0 to 1.19.1), a simple subject line is
sufficient:

```
Update Crystal to 1.19.1
```

Do not co-author commits.

## Git workflow

- Use dashes instead of slashes for branch names: `feature-new-functionality`
- Do not use: `feature/new-functionality`
- Create worktrees in `.worktrees/` directory when needed

## CI/CD

The GitHub Actions workflow:

- Automatically detects changes to `docker/` directories
- Builds only the affected versions on pull requests
- Pushes multi-arch images to `ghcr.io/luislavena/hydrofoil-crystal` on main
- Can be manually triggered to build specific or all versions

## Testing

The `goss.yaml` file defines container validation tests:

- Verifies Crystal and Shards are installed and functional
- Checks that required packages are present (curl, git, tmux, tzdata)
- Validates fixuid setup and user configuration
- Tests basic Crystal compilation with OpenSSL and YAML
