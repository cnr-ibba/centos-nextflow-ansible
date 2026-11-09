# CLAUDE.md

## Purpose
User-level Ansible playbook that configures a user's `$HOME` on a CentOS 8.x HPC cluster (target: CINECA Galileo100) with: dotfiles, SDKMAN + Java, Nextflow, Miniconda and the related environment variables, following https://bioinfo-guidelines.readthedocs.io (Nextflow, SLURM and Conda sections).

**Success criterion:** `uv run ansible-playbook site.yml --check --diff -l g100` against one's own G100 user must report `changed=0`. Every run after the first must also report `changed=0` in non-check mode.

The repo starts from the `acch/ansible-boilerplate` boilerplate (`site.yml` → group playbook → `roles/`). Keep that structure.

## Rules
- User-level only: **never root, never `become`**, never write outside `$HOME`.
- `$WORK` and `$CINECA_SCRATCH` stay **literal** in generated files (the shell expands them at runtime, not Ansible).
- No tracked usernames, private hosts or secrets: `ansible_user` lives in a per-person git-ignored file (only an `*.example` is tracked).
- Versions are **always pinned** (Java/SDKMAN candidate, Nextflow, Miniconda, dotfiles commit) in `group_vars/all.yml`. No `latest`.
- Idempotence is mandatory: `creates:`/`stat` for installers, explicit `changed_when` on every `shell`/`command`, prefer `template`/`blockinfile`/`file`.
- All files in this repo are written in English.

## Out of scope (do not implement here)
- SSH, step client, ssh-agent, key generation (valid ~12h): assume `ansible g100 -m ping` works like a normal pubkey login.
- Nextflow as a SLURM job (sbatch, account, partition, qos): defined in each project.
- The Nextflow `cineca` profile: comes from https://github.com/cnr-ibba/nf-configs, cloned in `$WORK`, outside this repo.

## Components
Implemented:

| Role | What it does |
|---|---|
| `common` | sanity checks: ping, writable `$HOME`, non-root user |
| `micromamba` | `get_url` of the plain `micromamba-linux-64` binary (sha256-checked, pinned `micromamba_version`) into `~/bin`; space is limited. The `.tar.bz2` used by the galaxy role is a conda package and would scatter `info/` files in `~/bin` |
| `galaxyproject.miniconda` | vendored in `galaxy_roles/` from Ansible Galaxy (pinned in `requirements.yml`, committed). It does not install anything here (binary already there); it is kept to create conda envs. `miniconda_update: false` (self-update breaks `changed=0`) |
| `dotfiles` | clones https://github.com/bunop/dotfiles (branch `cineca`, once: `dotfiles_update: false`) into `~/dotfiles` and runs `bin/install bash`; runs last. A read-only drift check makes `--check` truthful. First run on a user with real `~/.bashrc`/`~/.bash_profile` moves them to `.bak`. Its `bash_profile` already exports `NXF_*`, `PRJ_ACCOUNT` (from `~/.ch_acc.def`), SDKMAN init and the mamba init: **do not duplicate them in other roles** |
| `sdkman` | installs SDKMAN (`ci=true&rcupdate=false`: the dotfiles already source it) and the pinned Temurin Java (`sdkman_java_version`, use the identifier printed by `sdk list java`, e.g. `21.0.13.0+9-tem`) |
| `nextflow` | `get_url` of the plain release launcher (sha256-checked, pinned `nextflow_version`) into `~/bin`, plus `~/.nextflow/config` (slurm executor). `NXF_*` come from the dotfiles |
| `jq` | `get_url` of the static `jq-linux-amd64` binary (sha256-checked, pinned `jq_version`) into `~/bin`; needed by `squeue.sh`/`sacct.sh` |
| `gists` | clones the `bin_gists` (fix_permissions, squeue, sacct, rotate_stuff) once into `~/bin/<gist id>` and symlinks the script into `~/bin` (relative link, as in prod). **Exception to the pinning rule**: they track `master` with `update: false` and are refreshed by hand with `git pull` |
| `condarc` | `~/.condarc`: bioconda, conda-forge, nodefaults, strict priority. If the dotfiles ever ship `.condarc` too, drop one of the two |

Planned:

| Role | What it does |
|---|---|
| `nf-core` env | declared via `miniconda_conda_environments` with an **absolute** path under `~/.conda/envs` (the dotfiles export `MAMBA_EXE=$HOME/bin/micromamba`, `MAMBA_ROOT_PREFIX=$HOME/.conda`) |

`NXF_*` variables documented by the guide (`~/.bash_profile` on Red Hat): `NXF_EXECUTOR=slurm`, `NXF_OPTS="-Xms500M -Xmx4G"`, `NXF_SINGULARITY_CACHEDIR="$WORK/nxf_singularity_cache"`, `NXF_WORK="$CINECA_SCRATCH/nxf_work"`, `NXF_OFFLINE='true'`, `NXF_ANSI_LOG='false'`. `~/.nextflow/config`: `executor { queueSize=50; submitRateLimit='50/2min' }` (no `name`: `executor.name` in the config beats `NXF_EXECUTOR`, so `NXF_EXECUTOR=slurm` from the dotfiles stays the default and `NXF_EXECUTOR=local` works, e.g. inside a job) (the author's own value from his production `config.bak`; the guide says `'10 sec'`). Config order, lowest to highest: `~/.nextflow/config`, project `nextflow.config`, launch-dir `nextflow.config`, `-c`; the `galileo` profile of nf-configs sets `process.executor='slurm'`, `queueSize=100`, `submitRateLimit='50/2min'` and wins over this file. Nextflow 26.x requires Java 17–26 (24.10.x: Java ≥ 11). To test `nextflow run hello` in the container: `NXF_OFFLINE=false` (to pull `nextflow-io/hello`), `NXF_EXECUTOR=local` (no `sbatch` in the container). `NXF_WORK`/`NXF_TEMP` already resolve to existing dirs.

Before duplicating an env var, check what the dotfiles `bash` module already does. Before writing a new role, check whether the author already has an equivalent one to reuse.

## Vendored roles
Third-party roles live in `galaxy_roles/` (in `roles_path`), are committed, and are declared in `requirements.yml`. Install/update: `uv run ansible-galaxy role install -p galaxy_roles -r requirements.yml --force`. Do not edit them by hand.

## Commands
```
uv sync                                            # create the pinned ansible environment
cp inventory.example.yml inventory.local.yml       # git-ignored, holds your username
make up | ping | down                              # test container (docker/, port 2222)
uv run ansible-playbook site.yml --list-hosts
uv run ansible-playbook site.yml --check --diff -l g100   # final test: changed=0
uv run ansible-playbook site.yml -l docker                # converge on the test container
```

## Test environment (Docker, CentOS 8.3)
`centos:8.3.2011` container with sshd and a non-root user taken from `inventory.local.yml`, home `/g100/home/userexternal/<user>`; `$WORK`/`$CINECA_SCRATCH`/`$TMPDIR=/scratch_local` are set by `/etc/profile.d/cineca.sh` (fake account `test_account`; the user's primary group is `interactive`, gid 25200, as on G100, which is what enables `TMPDIR`). CentOS 8 is EOL: rewrite the repos to `vault.centos.org` in the Dockerfile. The container has no real SLURM, `$WORK` or `$CINECA_SCRATCH`: simulate them with environment variables and only verify generated files/binaries. After the first converge, a second converge must report `changed=0`.

## Target Python
G100 ships Python 3.6.8 (same as the CentOS 8 container). ansible-core 2.17+ needs Python ≥ 3.7 on the target, so the controller uses **ansible-core 2.16** (the last release supporting 3.6 targets), pinned in `pyproject.toml`/`uv.lock`.

**Always run ansible through the project's uv environment**: `uv run ansible …`, `uv run ansible-playbook …`, `uv run ansible-inventory …`. Never use a system/global ansible. Bumping the version requires re-checking Python 3.6 target support.

## Known limits
`--check` does not simulate `shell`/installer tasks: use `check_mode: false` only on read-only tasks (e.g. detecting the installed version) and gate installers on `creates:`/`stat`.
