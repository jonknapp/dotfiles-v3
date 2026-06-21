---
name: opencode-in-container
description: Use this skill whenever you need to install a new program,
  understand what programs are installed, or start a new session.
---

# opencode in a container

You are running in a minimal Docker/Podman container. Some programs you
expect to be installed may not be there yet and you'll need to prompt to
confirm their installation.

## Start a New Session

In case the container does not include `fd`, we should install it so it's
availble to use.

## Install a Program

The container should have apk which can install programs (ex: `apk add git`).

You will want to update the local cache with `apk update` before installing
any programs.

### Program Restrictions

We want to minimize the number of programs that get installed. We should
prompt for confirmation before installing the following:

- nodejs
- python
- ruby

Once installed, they can be used as normal.
