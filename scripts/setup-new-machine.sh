#!/usr/bin/env bash
# setup-new-machine: one-time, idempotent host setup for this flake.
#
# Run with:
#   nix run .#setup-new-machine -- [--yes] [--dry-run]
#
# Steps are safe to re-run. Every change is shown as a diff and confirmed
# before it is written, existing files are backed up, and existing values are
# never dropped without asking.
#
# Values are injected by the Nix package (modules/outputs/setup-new-machine.nix):
#   SETUP_CACHE_SUBSTITUTER  binary cache URL
#   SETUP_CACHE_PUBLIC_KEY   binary cache public key ("name:base64")
#
# Overrides (mainly for testing):
#   SETUP_SYSTEM_NIX_CONF    default: /etc/nix/nix.conf
#   SETUP_USER_NIX_CONF      default: ${XDG_CONFIG_HOME:-~/.config}/nix/nix.conf
#   SETUP_NIX_DAEMON_SOCKET  default: /nix/var/nix/daemon-socket/socket
#   SETUP_VYKAR_CONFIG_DIR   default: ${XDG_CONFIG_HOME:-~/.config}/vykar
set -euo pipefail

PROG=setup-new-machine

ASSUME_YES=false
DRY_RUN=false
MODE="" # daemon | single-user (auto-detected unless --mode is given)

SYSTEM_NIX_CONF=${SETUP_SYSTEM_NIX_CONF:-/etc/nix/nix.conf}
USER_NIX_CONF=${SETUP_USER_NIX_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf}
NIX_DAEMON_SOCKET=${SETUP_NIX_DAEMON_SOCKET:-/nix/var/nix/daemon-socket/socket}
VYKAR_CONFIG_DIR=${SETUP_VYKAR_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/vykar}

# 1Password item holding the vykar repository encryption passphrase, and the
# systemd user credential it is stored as (name and file must match
# `passcommand` in modules/home-manager/vykar/config.yaml.template).
VYKAR_PASSPHRASE_REF=op://cli/vykar/password
VYKAR_CREDENTIAL_NAME=vykar-passphrase
VYKAR_CREDENTIAL_FILE=$VYKAR_CONFIG_DIR/passphrase.cred

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# --------------------------------------------------------------------------
# Output / prompt helpers
# --------------------------------------------------------------------------

if [[ -t 1 ]]; then
  C_BOLD=$'\e[1m' C_BLUE=$'\e[34m' C_YELLOW=$'\e[33m' C_RED=$'\e[31m' C_GREEN=$'\e[32m' C_RESET=$'\e[0m'
else
  C_BOLD="" C_BLUE="" C_YELLOW="" C_RED="" C_GREEN="" C_RESET=""
fi

header() { printf '\n%s==> %s%s\n' "$C_BOLD" "$*" "$C_RESET"; }
info() { printf '%s::%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok() { printf '%s ok%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%swarning:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die() {
  printf '%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
  exit 1
}

# confirm QUESTION [DEFAULT=y|n] -> returns 0 for yes, 1 for no.
confirm() {
  local question=$1 default=${2:-y} hint reply
  if [[ $default == y ]]; then hint="[Y/n]"; else hint="[y/N]"; fi

  # Nothing is written in a dry run, so answer with the default to show the
  # full set of changes.
  if $ASSUME_YES || $DRY_RUN; then
    local why=--yes
    if $DRY_RUN; then why=--dry-run; fi
    printf '%s %s %s\n' "$question" "$hint" "$default ($why)"
    [[ $default == y ]]
    return
  fi

  while true; do
    printf '%s %s ' "$question" "$hint"
    if ! read -r reply; then
      printf '\n'
      die "no input available; re-run interactively or pass --yes"
    fi
    reply=${reply:-$default}
    case ${reply,,} in
      y | yes) return 0 ;;
      n | no) return 1 ;;
      *) printf 'Please answer y or n.\n' ;;
    esac
  done
}

usage() {
  cat <<EOF
Usage: $PROG [options]

One-time setup for a new machine using this flake. Safe to re-run.

Steps:
  nix-binary-cache   Trust the ${SETUP_CACHE_SUBSTITUTER:-<cache>} binary cache.
                     multi-user (daemon): $SYSTEM_NIX_CONF (via sudo) + daemon restart
                     single-user:         $USER_NIX_CONF
  1password-cli-group
                     Create the onepassword-cli group and add the current user
                     (Linux only, via sudo) for \`op\` desktop app integration.
  vykar              Encrypt the vykar passphrase from 1Password as a systemd
                     user credential ($VYKAR_CREDENTIAL_FILE)
                     and render $VYKAR_CONFIG_DIR/config.yaml
                     from config.yaml.template with \`op inject\`.
                     Skipped until home-manager has installed vykar.

Options:
  -y, --yes                    Accept the default answer for every prompt.
  -n, --dry-run                Show what would change without writing anything.
      --mode daemon|single-user
                               Override the detected Nix installation type.
  -h, --help                   Show this help.
EOF
}

# --------------------------------------------------------------------------
# Privilege / file helpers
# --------------------------------------------------------------------------

# Whether writing PATH (creating it or its parent dir) requires root.
needs_root() {
  local path=$1 dir
  if [[ -e $path ]]; then
    [[ ! -w $path ]]
    return
  fi
  dir=$(dirname -- "$path")
  while [[ ! -e $dir ]]; do dir=$(dirname -- "$dir"); done
  [[ ! -w $dir ]]
}

# Run a command, using sudo when the current user is not root.
as_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    command -v sudo >/dev/null || die "sudo is required to run: $*"
    sudo "$@"
  fi
}

# Files managed by NixOS / nix-darwin / home-manager are symlinks (usually into
# /nix/store or /etc/static) and must be configured declaratively instead.
is_managed_symlink() {
  [[ -L $1 ]]
}

# apply_file TARGET NEW_CONTENT_FILE
# Shows a diff, confirms, backs up TARGET, and writes it (using sudo if
# needed). Returns 0 if TARGET was changed, 1 if nothing was written.
apply_file() {
  local target=$1 new=$2 current="$TMP_DIR/current" use_root=false backup

  if [[ -e $target ]]; then cp -- "$target" "$current"; else : >"$current"; fi

  if cmp -s -- "$current" "$new"; then
    ok "$target is already up to date"
    return 1
  fi

  info "Proposed changes to $target:"
  diff -u --label "$target (current)" --label "$target (new)" -- "$current" "$new" || true

  if $DRY_RUN; then
    info "dry run: not writing $target"
    return 1
  fi

  needs_root "$target" && use_root=true
  local question="Write these changes to $target?"
  $use_root && question="Write these changes to $target (requires sudo)?"
  if ! confirm "$question" y; then
    warn "skipped writing $target"
    return 1
  fi

  run() { if $use_root; then as_root "$@"; else "$@"; fi; }

  if [[ -e $target ]]; then
    backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
    run cp -p -- "$target" "$backup"
    info "backed up previous version to $backup"
    # cp onto an existing file keeps its owner and permissions.
    run cp -- "$new" "$target"
  else
    run mkdir -p -- "$(dirname -- "$target")"
    run install -m 0644 -- "$new" "$target"
  fi
  ok "wrote $target"
  return 0
}

# --------------------------------------------------------------------------
# nix.conf list-setting editing
#
# nix.conf semantics: `name = a b` replaces the list, `extra-name = c` appends
# to it, later lines win, and `#` starts a comment. The helpers below compute
# the *effective* value of a setting, so a value in an `extra-` line that is
# later reset by a plain `name =` line is correctly treated as missing.
# --------------------------------------------------------------------------

# analyze_setting FILE NAME VALUE STALE_PREFIX
# Prints one record per line:
#   match <lineno>            a line setting NAME or extra-NAME
#   stale <lineno> <token>    a token starting with STALE_PREFIX that != VALUE
#   effective <0|1>           whether VALUE is in the effective list
analyze_setting() {
  awk -v name="$2" -v value="$3" -v prefix="$4" '
    {
      line = $0
      sub(/#.*/, "", line)
      if (line !~ ("^[[:space:]]*(extra-)?" name "[[:space:]]*=")) next
      is_extra = (line ~ /^[[:space:]]*extra-/)
      rhs = line
      sub(/^[^=]*=/, "", rhs)
      if (!is_extra) split("", eff)
      n = split(rhs, toks, /[[:space:]]+/)
      for (i = 1; i <= n; i++) {
        if (toks[i] == "") continue
        eff[toks[i]] = 1
        if (prefix != "" && index(toks[i], prefix) == 1 && toks[i] != value)
          print "stale", NR, toks[i]
      }
      print "match", NR
    }
    END { print "effective", ((value in eff) ? 1 : 0) }
  ' "$1"
}

# edit_line FILE LINENO append NEW
# edit_line FILE LINENO replace NEW OLD
# Rewrites the value list of one line in place, preserving any trailing
# comment and avoiding duplicates.
edit_line() {
  local file=$1 lineno=$2 op=$3 new=$4 old=${5:-}
  awk -v n="$lineno" -v op="$op" -v new="$new" -v old="$old" '
    NR == n {
      code = $0; comment = ""
      p = index($0, "#")
      if (p > 0) { code = substr($0, 1, p - 1); comment = substr($0, p) }
      eq = index(code, "=")
      lhs = substr(code, 1, eq)
      m = split(substr(code, eq + 1), t, /[[:space:]]+/)
      out = ""; split("", seen)
      for (i = 1; i <= m; i++) {
        tok = t[i]
        if (tok == "") continue
        if (op == "replace" && tok == old) tok = new
        if (tok in seen) continue
        seen[tok] = 1
        out = out " " tok
      }
      if (op == "append" && !(new in seen)) out = out " " new
      $0 = lhs out (comment != "" ? " " comment : "")
    }
    { print }
  ' "$file" >"$file.tmp"
  mv -- "$file.tmp" "$file"
}

print_line() { awk -v n="$2" 'NR == n { print; exit }' "$1"; }

# ensure_list_value FILE NAME VALUE [STALE_PREFIX]
# Makes VALUE part of the effective NAME list in FILE (a working copy).
ensure_list_value() {
  local file=$1 name=$2 value=$3 prefix=${4:-}
  local kind lineno token last_match="" effective=0
  local -a stale=()

  while read -r kind lineno token; do
    case $kind in
      match) last_match=$lineno ;;
      stale) stale+=("$lineno $token") ;;
      effective) effective=$lineno ;;
    esac
  done < <(analyze_setting "$file" "$name" "$value" "$prefix")

  # An existing value for the same key name (e.g. a rotated public key) would
  # be overwritten: always ask.
  local entry
  for entry in ${stale[@]+"${stale[@]}"}; do
    lineno=${entry%% *}
    token=${entry#* }
    info "line $lineno has a different value for ${prefix%:}:"
    printf '    %s\n' "$(print_line "$file" "$lineno")"
    if confirm "  Replace '$token' with '$value'?" y; then
      edit_line "$file" "$lineno" replace "$value" "$token"
    else
      warn "keeping existing value '$token' on line $lineno"
    fi
  done

  if ((${#stale[@]} > 0)); then
    # Re-evaluate after replacements.
    effective=$(analyze_setting "$file" "$name" "$value" "$prefix" | awk '$1 == "effective" { print $2 }')
  fi

  if [[ $effective == 1 ]]; then
    ok "$name already includes $value"
    return
  fi

  if [[ -n $last_match ]]; then
    # Appending to the last line that sets this option guarantees no later
    # line resets it, and keeps every value that is already there.
    info "$name is already set on line $last_match:"
    printf '    %s\n' "$(print_line "$file" "$last_match")"
    if confirm "  Add '$value' to this line (existing values are kept)?" y; then
      edit_line "$file" "$last_match" append "$value"
    else
      warn "not adding $value to $name"
    fi
    return
  fi

  # Not configured at all: append a new extra- line.
  if [[ -s $file && -n $(tail -c 1 -- "$file") ]]; then printf '\n' >>"$file"; fi
  printf 'extra-%s = %s\n' "$name" "$value" >>"$file"
}

# --------------------------------------------------------------------------
# Nix installation detection
# --------------------------------------------------------------------------

detect_nix_mode() {
  case ${NIX_REMOTE:-} in
    daemon | unix://*)
      echo daemon
      return
      ;;
    local | local\?* | /*)
      echo single-user
      return
      ;;
    "") ;;
    *) die "unsupported NIX_REMOTE='$NIX_REMOTE'; pass --mode daemon|single-user" ;;
  esac

  if [[ -S $NIX_DAEMON_SOCKET ]] ||
    [[ -e /etc/systemd/system/nix-daemon.service ]] ||
    [[ -e /Library/LaunchDaemons/org.nixos.nix-daemon.plist ]]; then
    echo daemon
  else
    echo single-user
  fi
}

restart_nix_daemon() {
  local -a cmd=()
  if command -v systemctl >/dev/null && systemctl cat nix-daemon.service >/dev/null 2>&1; then
    cmd=(systemctl restart nix-daemon.service)
  elif [[ $(uname -s) == Darwin ]] && command -v launchctl >/dev/null; then
    cmd=(launchctl kickstart -k system/org.nixos.nix-daemon)
  fi

  if ((${#cmd[@]} == 0)); then
    warn "could not find the nix-daemon service; restart it manually for the change to take effect"
    return
  fi

  if confirm "Restart nix-daemon now (required for the change to take effect)?" y; then
    if as_root "${cmd[@]}"; then
      ok "restarted nix-daemon"
    else
      warn "failed to restart nix-daemon; run: sudo ${cmd[*]}"
    fi
  else
    warn "remember to run: sudo ${cmd[*]}"
  fi
}

# --------------------------------------------------------------------------
# Steps
# --------------------------------------------------------------------------

step_nix_binary_cache() {
  header "Nix binary cache: $SETUP_CACHE_SUBSTITUTER"

  local mode=$MODE how="using" target substituters_option key_prefix
  if [[ -z $mode ]]; then
    mode=$(detect_nix_mode)
    how="detected"
  fi
  key_prefix="${SETUP_CACHE_PUBLIC_KEY%%:*}:"

  if [[ $mode == daemon ]]; then
    # Untrusted clients may only use substituters the daemon lists in
    # trusted-substituters; the flake requests it via extra-substituters.
    target=$SYSTEM_NIX_CONF
    substituters_option=trusted-substituters
    info "$how a multi-user (daemon) Nix install; configuring $target"
  else
    target=$USER_NIX_CONF
    substituters_option=substituters
    info "$how a single-user Nix install; configuring $target"
  fi

  if is_managed_symlink "$target"; then
    warn "$target is a symlink ($(readlink -- "$target")), so it is managed declaratively"
    warn "(NixOS, nix-darwin or home-manager). Add these settings there instead:"
    printf '    %s = [ "%s" ];\n' "nix.settings.$substituters_option" "$SETUP_CACHE_SUBSTITUTER"
    printf '    %s = [ "%s" ];\n' "nix.settings.trusted-public-keys" "$SETUP_CACHE_PUBLIC_KEY"
    return
  fi

  local work="$TMP_DIR/nix.conf"
  if [[ -e $target ]]; then
    [[ -r $target ]] || die "cannot read $target"
    cp -- "$target" "$work"
  else
    : >"$work"
  fi

  ensure_list_value "$work" "$substituters_option" "$SETUP_CACHE_SUBSTITUTER"
  ensure_list_value "$work" trusted-public-keys "$SETUP_CACHE_PUBLIC_KEY" "$key_prefix"

  if apply_file "$target" "$work" && [[ $mode == daemon ]]; then
    restart_nix_daemon
  fi

  if [[ $mode == daemon && -f $USER_NIX_CONF ]] &&
    analyze_setting "$USER_NIX_CONF" trusted-public-keys "$SETUP_CACHE_PUBLIC_KEY" "" |
    awk '$1 == "match" { found = 1 } END { exit !found }'; then
    warn "$USER_NIX_CONF sets trusted-public-keys; unless you are in the daemon's"
    warn "trusted-users this is ignored and produces a warning on every nix command."
  fi
}

# 1Password desktop only trusts `op` when it runs with the onepassword-cli
# group. Nix store paths can't be chgrp'd/setgid, so the home-manager `op`
# wrapper (modules/home-manager/1password.nix) runs it via
# `sg onepassword-cli`, which needs the group to exist and the user to be a
# member. Not needed for the 1Password SSH agent.
step_1password_cli_group() {
  local group=onepassword-cli user
  user=$(id -un)
  header "1Password CLI group: $group"

  if [[ $(uname -s) != Linux ]]; then
    ok "not Linux; skipping"
    return
  fi
  command -v getent >/dev/null || die "getent is required to check groups"

  if getent group "$group" >/dev/null; then
    ok "group $group exists"
  elif $DRY_RUN; then
    info "dry run: would run: sudo groupadd -f $group"
  elif confirm "Create group '$group' (requires sudo)?" y; then
    as_root groupadd -f "$group"
    ok "created group $group"
  else
    warn "skipped creating group $group; \`op\` desktop app integration will not work"
    return
  fi

  if getent group "$group" | cut -d: -f4 | tr ',' '\n' | grep -qxF -- "$user"; then
    ok "$user is a member of $group"
  elif $DRY_RUN; then
    info "dry run: would run: sudo usermod -aG $group $user"
  elif confirm "Add $user to group '$group' (requires sudo)?" y; then
    as_root usermod -aG "$group" "$user"
    ok "added $user to $group"
  else
    warn "skipped adding $user to $group; \`op\` desktop app integration will not work"
  fi
}

# vykar (modules/home-manager/vykar.nix) reads its repository passphrase from a
# systemd user credential via `passcommand` (no keyring/Secret Service needed,
# and it decrypts without prompting, so scheduled backups work unattended). Its
# other secrets are injected from 1Password into config.yaml. vykar, `op` and
# the template are all installed by home-manager, and `op` needs the 1Password
# app signed in, so on a fresh machine this step is skipped; re-run the script
# once that is done.
step_vykar() {
  header "vykar backup config"

  if ! command -v vykar >/dev/null; then
    ok "vykar is not installed yet; skipping (re-run after home-manager switch)"
    return
  fi

  local tool
  for tool in op systemd-creds; do
    if ! command -v "$tool" >/dev/null; then
      warn "$tool not found; skipping vykar setup"
      return
    fi
  done

  if [[ ! -f $VYKAR_CONFIG_DIR/config.yaml.template ]]; then
    warn "$VYKAR_CONFIG_DIR/config.yaml.template not found; skipping vykar setup"
    warn "(it is installed by the home-manager vykar module)"
    return
  fi

  vykar_store_passphrase || true
  vykar_render_config
}

# Same decrypt as `passcommand` in the template, which also locates the file
# via $XDG_CONFIG_HOME (default ~/.config). Prints the passphrase.
vykar_decrypt_passphrase() {
  systemd-creds --user decrypt --no-ask-password \
    --name="$VYKAR_CREDENTIAL_NAME" "${1:-$VYKAR_CREDENTIAL_FILE}" -
}

# Encrypts the passphrase from 1Password into a systemd user credential, unless
# a credential that decrypts on this machine already exists.
vykar_store_passphrase() {
  local cred=$VYKAR_CREDENTIAL_FILE tmp="$VYKAR_CREDENTIAL_FILE.tmp"
  local passphrase decrypted

  if [[ -e $cred ]]; then
    if vykar_decrypt_passphrase >/dev/null 2>&1; then
      ok "vykar passphrase credential exists: $cred"
      return 0
    fi
    # Credentials are bound to the user, machine-id and host key / TPM, so a
    # file copied from another machine or an old install won't decrypt.
    warn "$cred exists but cannot be decrypted on this machine"
  fi

  if $DRY_RUN; then
    info "dry run: would encrypt $VYKAR_PASSPHRASE_REF into $cred with systemd-creds --user"
    return 0
  fi

  if ! confirm "Encrypt the vykar passphrase from 1Password into $cred (systemd-creds --user)?" y; then
    warn "skipped; vykar's passcommand will fail until the credential exists"
    return 1
  fi

  # Read into a variable first: piping `op read` straight into
  # `systemd-creds encrypt` would store an empty secret if `op` fails.
  if ! passphrase=$(op read "$VYKAR_PASSPHRASE_REF") || [[ -z $passphrase ]]; then
    warn "could not read $VYKAR_PASSPHRASE_REF; make sure 1Password is running and"
    warn "signed in, with Settings > Developer > \"Integrate with 1Password CLI\" enabled"
    return 1
  fi

  mkdir -p -- "$VYKAR_CONFIG_DIR"
  # printf is a builtin, so the passphrase never appears in a process's argv.
  if ! (umask 077 && printf '%s' "$passphrase" |
    systemd-creds --user encrypt --name="$VYKAR_CREDENTIAL_NAME" - "$tmp"); then
    rm -f -- "$tmp"
    warn "systemd-creds encrypt failed; user credentials need systemd >= 256"
    warn "(check with: systemd-creds --version)"
    return 1
  fi

  # Make sure vykar's passcommand will get the same passphrase back before
  # replacing anything.
  if ! decrypted=$(vykar_decrypt_passphrase "$tmp") || [[ $decrypted != "$passphrase" ]]; then
    rm -f -- "$tmp"
    warn "encrypted credential did not decrypt back to the passphrase; not saving it"
    return 1
  fi

  mv -f -- "$tmp" "$cred"
  ok "encrypted vykar passphrase into $cred"
}

# `op inject` inserts values verbatim, and the template keeps op:// references
# in YAML single quotes. Compares TEMPLATE and RENDERED line by line and fails
# (printing only line numbers, never values) if an injected value:
#   - contains a single quote: the quote count on that line changes, and the
#     YAML string would end early;
#   - contains a newline: the line count changes;
#   - contains "${": vykar expands that before parsing YAML, with no escape.
vykar_check_injected() {
  awk '
    NR == FNR { tpl[FNR] = $0; n = FNR; next }
    {
      m = FNR
      if (!(FNR in tpl) || !index(tpl[FNR], "op://")) next
      t = tpl[FNR]; r = $0
      if (gsub(/\047/, "", t) != gsub(/\047/, "", r) ||
          (index($0, "${") && !index(tpl[FNR], "${"))) {
        print "  line " FNR
        bad = 1
      }
    }
    END {
      if (m != n) { print "  line count changed (" n " -> " m ")"; bad = 1 }
      exit bad
    }
  ' "$1" "$2"
}

# Renders config.yaml from the home-manager template, resolving op:// secret
# references with `op inject`. The result contains secrets, so it is written
# with mode 0600, no diff is printed, and no backup is kept: the template plus
# 1Password is the source of truth, so a backup would only be another
# plaintext copy of the secrets.
vykar_render_config() {
  local template="$VYKAR_CONFIG_DIR/config.yaml.template"
  local target="$VYKAR_CONFIG_DIR/config.yaml"
  local rendered="$TMP_DIR/vykar-config.yaml"

  vykar_remove_config_backups "$target"

  if is_managed_symlink "$target"; then
    warn "$target is a symlink ($(readlink -- "$target")); leaving it alone"
    return
  fi

  if $DRY_RUN; then
    info "dry run: would render $target from $template with \`op inject\`"
    return
  fi

  # op inject treats every op:// in the file as a secret reference, comments
  # included, and fails on (or worse, resolves) one written in a comment.
  local commented
  if commented=$(grep -n '#.*op://' -- "$template"); then
    warn "$template mentions op:// in a comment; op inject would parse it."
    warn "Reword these lines in modules/home-manager/vykar/config.yaml.template:"
    local line
    while IFS= read -r line; do printf '    %s\n' "$line"; done <<<"$commented" >&2
    return
  fi

  if ! (umask 077 && op inject --in-file "$template" >"$rendered"); then
    warn "op inject failed; make sure 1Password is running and signed in, with"
    warn "Settings > Developer > \"Integrate with 1Password CLI\" enabled"
    return
  fi

  local problems
  if ! problems=$(vykar_check_injected "$template" "$rendered"); then
    warn "not writing $target: a 1Password value would corrupt the config"
    warn "(contains a single quote, newline or dollar-brace placeholder):"
    warn "$problems"
    return
  fi

  if [[ -e $target ]]; then
    if cmp -s -- "$target" "$rendered"; then
      ok "$target is already up to date"
      return
    fi
    info "$target differs from the rendered template (diff not shown: it contains secrets)"
    info "local edits are not kept; make lasting changes in config.yaml.template"
    if ! confirm "Overwrite $target with the rendered template?" y; then
      warn "kept existing $target"
      return
    fi
  fi

  # Write next to the target and rename, so vykar-gui (which reloads the config
  # on change) never sees a missing or half-written file.
  if install -m 0600 -- "$rendered" "$target.tmp" && mv -f -- "$target.tmp" "$target"; then
    ok "wrote $target"
  else
    rm -f -- "$target.tmp"
    warn "failed to write $target"
  fi
}

# Earlier versions of this script kept config.yaml.bak-<timestamp> copies,
# which hold plaintext secrets (and possibly the repository passphrase, from
# before it moved to a systemd credential). Offers to delete them.
vykar_remove_config_backups() {
  local target=$1
  local -a backups=()
  local f

  for f in "$target".bak-*; do
    [[ -e $f ]] && backups+=("$f")
  done
  ((${#backups[@]} > 0)) || return 0

  warn "found old config backups containing plaintext secrets:"
  printf '    %s\n' "${backups[@]}" >&2
  if $DRY_RUN; then
    info "dry run: would delete them"
  elif confirm "Delete these backups?" y; then
    rm -f -- "${backups[@]}"
    ok "deleted ${#backups[@]} old config backup(s)"
  else
    warn "kept old config backups"
  fi
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

main() {
  while (($# > 0)); do
    case $1 in
      -y | --yes) ASSUME_YES=true ;;
      -n | --dry-run) DRY_RUN=true ;;
      --mode)
        (($# >= 2)) || die "--mode requires an argument"
        MODE=$2
        shift
        ;;
      --mode=*) MODE=${1#--mode=} ;;
      -h | --help)
        usage
        return 0
        ;;
      *)
        usage >&2
        die "unknown argument: $1"
        ;;
    esac
    shift
  done

  case $MODE in
    "" | daemon | single-user) ;;
    *) die "--mode must be 'daemon' or 'single-user'" ;;
  esac

  [[ -n ${SETUP_CACHE_SUBSTITUTER:-} && -n ${SETUP_CACHE_PUBLIC_KEY:-} ]] ||
    die "SETUP_CACHE_SUBSTITUTER and SETUP_CACHE_PUBLIC_KEY must be set; run via 'nix run .#$PROG'"

  $DRY_RUN && info "dry run: no files will be changed"

  step_nix_binary_cache
  step_1password_cli_group
  step_vykar

  header "Done"
}

main "$@"
