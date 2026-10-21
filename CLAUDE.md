# CLAUDE.md

## Purpose
User-level Ansible playbook that configures a user's `$HOME` on a CentOS 8.x HPC cluster (target: CINECA Galileo100) with: dotfiles, SDKMAN + Java, Nextflow, Miniconda and the related environment variables, following https://bioinfo-guidelines.readthedocs.io (Nextflow, SLURM and Conda sections).

**Success criterion:** `ansible-playbook site.yml --check --diff -l g100` against one's own G100 user must report `changed=0`. Every run after the first must also report `changed=0` in non-check mode.

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

## Planned components
| Role | What it does |
|---|---|
| `common` | sanity checks: ping, writable `$HOME`, non-root user |
| `dotfiles` | clones https://github.com/bunop/dotfiles (branch `cineca`, pinned commit) and runs `bin/install bash` (symlinks in `$HOME`, `.bak` backups) |
| `sdkman` | installs SDKMAN and the pinned Java |
| `nextflow` | pinned Nextflow, `~/.nextflow/config`; `NXF_*` variables only if not already in the dotfiles |
| `miniconda` | pinned installer, `nf-core` env (`pip install nf-core`) |

`NXF_*` variables documented by the guide (`~/.bash_profile` on Red Hat): `NXF_EXECUTOR=slurm`, `NXF_OPTS="-Xms500M -Xmx4G"`, `NXF_SINGULARITY_CACHEDIR="$WORK/nxf_singularity_cache"`, `NXF_WORK="$CINECA_SCRATCH/nxf_work"`, `NXF_OFFLINE='true'`, `NXF_ANSI_LOG='false'`. `~/.nextflow/config`: `executor { name='slurm'; queueSize=50; submitRateLimit='10 sec' }`. Nextflow ≥ 24.10.3 requires Java ≥ 11.

Before duplicating an env var, check what the dotfiles `bash` module already does. Before writing a new role, check whether the author already has an equivalent one to reuse.

## Commands
```
cp inventory.example.yml inventory.local.yml       # git-ignored, holds your username
make up | ping | down                              # test container (docker/, port 2222)
ansible-playbook site.yml --list-hosts
ansible-playbook site.yml --check --diff -l g100   # final test: changed=0
ansible-playbook site.yml -l docker                # converge on the test container
```

## Test environment (Docker, CentOS 8.3)
`centos:8.3.2011` container with sshd and a non-root user taken from `inventory.local.yml`, home `/g100/home/userexternal/<user>`; `$WORK`/`$CINECA_SCRATCH` are set by `/etc/profile.d/cineca.sh` (fake account `test_account`). CentOS 8 is EOL: rewrite the repos to `vault.centos.org` in the Dockerfile. The container has no real SLURM, `$WORK` or `$CINECA_SCRATCH`: simulate them with environment variables and only verify generated files/binaries. After the first converge, a second converge must report `changed=0`.

## Target Python
G100 ships Python 3.6.8 (same as the CentOS 8 container). ansible-core 2.17+ needs Python ≥ 3.7 on the target, so use **ansible-core ≤ 2.16** on the controller (2.16 is the last release supporting 3.6 targets).

## Known limits
`--check` does not simulate `shell`/installer tasks: use `check_mode: false` only on read-only tasks (e.g. detecting the installed version) and gate installers on `creates:`/`stat`.
