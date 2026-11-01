#!/usr/bin/env bash
# Install gost for host CONNECT (official go-gost release or go install).
# Writes to GOST_BIN_DIR (default ~/.local/bin) and prints PATH hint.
# Exit 0 if gost usable; non-zero if install failed (caller may fall back to Python).
set -euo pipefail
BIN_DIR="${GOST_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

# Success only when gost -V or gost -h actually runs.
# A wrong-arch binary still shows up in `command -v` and must not count as installed.
print_version() {
  local bin
  bin=$(command -v gost 2>/dev/null || true)
  if [[ -z "$bin" ]]; then
    return 1
  fi
  if "$bin" -V >/dev/null 2>&1; then
    echo "gost OK: $bin"
    "$bin" -V 2>&1 || true
    return 0
  fi
  if "$bin" -h >/dev/null 2>&1; then
    echo "gost OK: $bin"
    "$bin" -h 2>&1 | head -3 || true
    return 0
  fi
  echo "gost present but failed -V/-h: $bin" >&2
  return 1
}

if print_version; then
  exit 0
fi

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac
case "$OS" in
  linux|darwin) ;;
  *) echo "unsupported os: $OS" >&2; exit 1 ;;
esac

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 1) Prefer official GitHub release binary (go-gost/gost) for this OS/arch.
# Asset names vary by version; resolve latest via API when possible.
ASSET=""
API_JSON=""
if command -v curl >/dev/null 2>&1; then
  API_JSON=$(curl -fsSL "https://api.github.com/repos/go-gost/gost/releases/latest" 2>/dev/null || true)
fi
if [[ -n "$API_JSON" ]]; then
  # Match os/arch as whole tokens so amd64 does not select amd64v3, and linux does not select android.
  # OS_NAME/ARCH_NAME must be in the python process environment (not argv).
  ASSET=$(printf '%s' "$API_JSON" | OS_NAME="$OS" ARCH_NAME="$ARCH" python3 -c '
import json, sys, os, re
os_name = os.environ.get("OS_NAME", "")
arch = os.environ.get("ARCH_NAME", "")
if not os_name or not arch:
    sys.exit(0)
j = json.load(sys.stdin)
assets = j.get("assets") or []
cands = []
for a in assets:
    n = a.get("name") or ""
    u = a.get("browser_download_url") or ""
    nl = n.lower()
    if not (nl.endswith(".tar.gz") or nl.endswith(".tgz") or nl.endswith(".zip")):
        continue
    if "checksum" in nl or "sha256" in nl:
        continue
    tokens = set(re.split(r"[^a-z0-9]+", nl))
    if os_name not in tokens or arch not in tokens:
        continue
    if nl.endswith("_%s_%s.tar.gz" % (os_name, arch)) or nl.endswith("_%s_%s.tgz" % (os_name, arch)):
        score = 2
    elif nl.endswith(".tar.gz") or nl.endswith(".tgz"):
        score = 1
    else:
        score = 0
    cands.append((score, u))
cands.sort(key=lambda item: -item[0])
print(cands[0][1] if cands else "")
' 2>/dev/null || true)
fi

extract_and_place() {
  local archive="$1"
  local dest="$2"
  case "$archive" in
    *.zip)
      if command -v unzip >/dev/null 2>&1; then unzip -qo "$archive" -d "$TMP/out"
      else python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$archive" "$TMP/out"
      fi
      ;;
    *)
      mkdir -p "$TMP/out"
      tar -xzf "$archive" -C "$TMP/out"
      ;;
  esac
  local bin
  bin=$(find "$TMP/out" -type f -name gost 2>/dev/null | head -1 || true)
  if [[ -z "$bin" ]]; then
    bin=$(find "$TMP/out" -type f -perm -111 2>/dev/null | head -1 || true)
  fi
  [[ -n "$bin" ]] || return 1
  install -m 755 "$bin" "$dest/gost"
}

if [[ -n "$ASSET" ]]; then
  echo "downloading: $ASSET"
  if curl -fsSL "$ASSET" -o "$TMP/gost.archive" && [[ -s "$TMP/gost.archive" ]]; then
    if extract_and_place "$TMP/gost.archive" "$BIN_DIR" && print_version; then
      echo "PATH tip: export PATH=\"$BIN_DIR:\$PATH\"  # or symlink next to cloudflared"
      exit 0
    fi
    echo "release extract or verify failed; trying go install…" >&2
  else
    echo "release download empty or failed; trying go install…" >&2
  fi
fi

# 2) go install fallback
if command -v go >/dev/null 2>&1; then
  if GOBIN="$BIN_DIR" go install github.com/go-gost/gost/cmd/gost@latest; then
    if print_version; then
      echo "PATH tip: export PATH=\"$BIN_DIR:\$PATH\""
      exit 0
    fi
  fi
  echo "go install did not yield a working gost" >&2
fi

# 3) brew on macOS
if [[ "$OS" == darwin ]] && command -v brew >/dev/null 2>&1; then
  brew install gost 2>/dev/null || brew install go-gost/gost/gost 2>/dev/null || true
  if print_version; then exit 0; fi
fi

echo "gost install failed. Official releases: https://github.com/go-gost/gost/releases" >&2
echo "After manual install, ensure \`gost\` is on PATH (e.g. $BIN_DIR) then re-run start.sh." >&2
echo "Setup may fall back to Python connect_proxy.py only if gost cannot be installed." >&2
exit 1
