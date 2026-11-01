#!/usr/bin/env bash
# Load site inventory (site.env / inventory.env). Sourced only; no secrets.
# Search order:
#   1) $SITE_ENV if set and exists
#   2) ./site.env then ./inventory.env
#   3) sibling of $AUTH_FILE (or ./proxy.auth): site.env then inventory.env
# Only whitelisted keys; never override non-empty existing env.
# Forbidden in inventory files: password, token, JWT, proxy.auth contents.

_ctp_site_env_set_if_empty() {
  local k="$1" v="$2" cur sys
  # skip empty values
  [[ -n "$v" ]] || return 0
  cur="${!k:-}"
  # do not override explicit env — except bare shell HOSTNAME (machine name)
  # which would block loading cf-tunnel-proxy.<domain> from site.env on typical Linux
  if [[ -n "$cur" ]]; then
    if [[ "$k" == "HOSTNAME" ]]; then
      sys="$(hostname 2>/dev/null || true)"
      if [[ "$cur" == "$sys" || "$cur" == "${sys%%.*}" ]]; then
        :
      else
        return 0
      fi
    else
      return 0
    fi
  fi
  printf -v "$k" '%s' "$v"
  export "$k"
}

_ctp_site_env_apply_file() {
  local f="$1" line key val
  [[ -f "$f" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    # trim CR; skip blank / comment
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # KEY=VALUE (optional export / optional quotes)
    if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[2]}"
      val="${BASH_REMATCH[3]}"
      # strip surrounding quotes
      if [[ "$val" =~ ^\"(.*)\"$ ]]; then val="${BASH_REMATCH[1]}"; fi
      if [[ "$val" =~ ^\'(.*)\'$ ]]; then val="${BASH_REMATCH[1]}"; fi
      case "$key" in
        HOSTNAME|TUNNEL_ID|TUNNEL_NAME|ORIGIN_PORT|LISTEN_PORT|CFG|AUTH_FILE|ROLE|CFD|ACCESS_APP_URL|NOTES|METRICS_URL)
          _ctp_site_env_set_if_empty "$key" "$val"
          ;;
        *)
          # ignore unknown / forbidden keys (password, token, etc.)
          ;;
      esac
    fi
  done <"$f"
  return 0
}

ctp_load_site_env() {
  local f="" auth_dir=""
  if [[ -n "${SITE_ENV:-}" && -f "${SITE_ENV}" ]]; then
    f="${SITE_ENV}"
  elif [[ -f ./site.env ]]; then
    f=./site.env
  elif [[ -f ./inventory.env ]]; then
    f=./inventory.env
  else
    if [[ -n "${AUTH_FILE:-}" ]]; then
      auth_dir="$(dirname "${AUTH_FILE}")"
    elif [[ -f ./proxy.auth ]]; then
      auth_dir=.
    fi
    if [[ -n "${auth_dir}" ]]; then
      if [[ -f "${auth_dir}/site.env" ]]; then
        f="${auth_dir}/site.env"
      elif [[ -f "${auth_dir}/inventory.env" ]]; then
        f="${auth_dir}/inventory.env"
      fi
    fi
  fi
  [[ -n "$f" ]] || return 0
  _ctp_site_env_apply_file "$f" || true
  # LISTEN_PORT aliases ORIGIN_PORT when ORIGIN_PORT still empty
  if [[ -z "${ORIGIN_PORT:-}" && -n "${LISTEN_PORT:-}" ]]; then
    ORIGIN_PORT="${LISTEN_PORT}"
    export ORIGIN_PORT
  fi
  if [[ -z "${LISTEN_PORT:-}" && -n "${ORIGIN_PORT:-}" ]]; then
    LISTEN_PORT="${ORIGIN_PORT}"
    export LISTEN_PORT
  fi
  return 0
}
