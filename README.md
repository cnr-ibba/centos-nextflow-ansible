# centos-nextflow-ansible

User-level [Ansible](https://www.ansible.com/) playbook that configures the `$HOME` of a user on a CentOS 8 HPC cluster
(target: CINECA Galileo100, "G100") to run [Nextflow](https://www.nextflow.io/) pipelines, following the
[bioinfo-guidelines](https://bioinfo-guidelines.readthedocs.io) (Nextflow, SLURM and Conda sections).

It sets up dotfiles, a micromamba/conda environment with `nf-core` and `csvkit` envs, `~/.condarc`, SDKMAN + Java and Nextflow.

Principles:

- User-level only: never root, never `become`, nothing written outside `$HOME`.
- No usernames or secrets in the repository: your username lives in a git-ignored `inventory.local.yml`.
- All versions are pinned.
- Idempotent: after the first run, `--check` and every further run must report `changed=0`.

Out of scope: SSH/ssh-agent setup, running Nextflow as a SLURM job (defined in each project) and the Nextflow `cineca`
profile (from [cnr-ibba/nf-configs](https://github.com/cnr-ibba/nf-configs)).

The repository structure (`site.yml` → group playbook → `roles/`) comes from
[acch/ansible-boilerplate](https://github.com/acch/ansible-boilerplate) (MIT).

## Local setup and test environment

Your username is kept in `inventory.local.yml`, which is git-ignored:

Ansible runs from a [uv](https://docs.astral.sh/uv/) environment pinned in `pyproject.toml`/`uv.lock`
(ansible-core 2.16, the last release supporting the Python 3.6 of G100). **Always run ansible through it**
with `uv run`, never with a system-wide ansible:

```
uv sync
cp inventory.example.yml inventory.local.yml
# edit it: replace "yourusername" with your CINECA username (for both g100 and docker)
```

The `docker` host is a CentOS 8.3 container that mimics a G100 login node. Its home is
`/g100/home/userexternal/<your user>`, with `$WORK` and `$CINECA_SCRATCH` set for login shells.
Your ssh-agent keys (or `~/.ssh/*.pub`) are authorized in the container.

```
make up      # build the image with the user from inventory.local.yml and start it on 127.0.0.1:2222
make ping    # uv run ansible docker -m ping
make down    # remove the container
```

To open a shell in the test container (same user as in `inventory.local.yml`):

```
ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null <your user>@127.0.0.1
# or, without ssh, as root:
docker exec -it g100-test bash
# or, as your user:
docker exec -it -u <your user> g100-test bash -l
```

For `g100`, a valid ssh-agent session (CINECA step client) is assumed: `uv run ansible g100 -m ping` must work.

## Usage

Prefix every command with `uv run` (see [Local setup](#local-setup-and-test-environment)).

```
# Show the hosts that would be affected
uv run ansible-playbook site.yml --list-hosts

# Dry-run on your G100 user: must report changed=0 once configured
uv run ansible-playbook site.yml --check --diff -l g100

# Converge the test container (a second run must report changed=0)
uv run ansible-playbook site.yml -l docker

# Run a single component, using its tag
uv run ansible-playbook site.yml -l docker -t dotfiles
```

Use `-v`, `-vv` or `-vvv` for more verbose output.

## Configuration files

Hosts (and the username) are defined in `inventory.local.yml`, see [Local setup](#local-setup-and-test-environment).

### Playbooks

File | Description
---- | -----------
`site.yml` | Main playbook - imports all the others
`user_env.yml` | Configures the user's `$HOME` on all hosts (`g100` and `docker`)

### Roles

```
roles/
├── common/             Sanity checks: ping, non-root user, writable $HOME
├── micromamba/         micromamba binary (get_url, sha256-checked) in ~/bin
├── condapip/           creates the conda envs and pip-installs nf-core/tools and csvkit into their conda envs
├── condarc/            ~/.condarc (bioconda, conda-forge, nodefaults, strict priority)
└── dotfiles/           bunop/dotfiles (branch cineca) cloned in ~/dotfiles, `bin/install bash`
```

micromamba is used instead of Miniconda because space is limited. The `condapip` role creates the conda environments with it.

### Tags

```
uv run ansible-playbook site.yml --list-tags
```

Role | Tags
--- | ---
common | check
micromamba | micromamba
condapip | condapip
condarc | condarc
dotfiles | dotfiles

## Copyright and license

Copyright (c) 2017 Achim Christ (original boilerplate), Copyright (c) 2026 Paolo Cozzi.
Released under the [MIT license](LICENSE).
