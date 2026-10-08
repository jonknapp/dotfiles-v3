---
name: opencode-in-container
description: Use this skill whenever you need to install a new program,
  understand what programs are installed, run a program that's missing, or start
  a new session.
---

# opencode in a container

You are running in a minimal Docker/Podman container. Some programs you
expect to be installed may not be there yet and you'll need to prompt to
confirm their installation or ask me to run the commands myself.

## Start a New Session

In case the container does not include `fd`, we should install it so it's
availble to use.

## Install a Program

The container should have apk which can install programs (ex: `apk add git`).

Update the local cache with `apk update` before installing any programs.

### Program Restrictions

Prompt for confirmation before installing the following:

- cargo
- nodejs
- python
- ruby
- rust

Once installed, they can be used as normal inside the container. If it's
decided that it will not be allowed to be installed, ask me to run commands
instead.
