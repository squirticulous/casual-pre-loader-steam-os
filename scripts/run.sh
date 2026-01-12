#!/bin/sh
set -e

cd "$(dirname "$(dirname "$(realpath -s "${0}")")")"

# Prefer project-local wine wrapper (Flatpak) if present
export PATH="$(pwd)/scripts:$PATH"

check_python_version() {
  python3 -c 'import sys; vi=sys.version_info; exit(not (vi.major==3 and vi.minor>=11))'
}

dep_missing() {
  printf '%s is not installed or not available, please install it\n' "${1}" >&2
}

# Basic checks
if [ "$(id -u)" -eq 0 ]; then
  printf "This script should not be run as root\n" >&2
  exit 1
fi

command -v python3 >/dev/null 2>&1 || { dep_missing python3; exit 1; }
check_python_version || { printf "Python 3.11+ required (found: %s)\n" "$(python3 -V)" >&2; exit 1; }

# venv + ensurepip must exist (SteamOS normally has them, but we check)
python3 -c 'import venv, ensurepip' >/dev/null 2>&1 || { dep_missing "python3-venv (venv + ensurepip)"; exit 1; }

# Wine: accept either a host wine binary OR the project wrapper calling Flatpak
if ! command -v wine >/dev/null 2>&1; then
  dep_missing "wine (host wine) OR Flatpak org.winehq.Wine with scripts/wine wrapper"
  exit 1
fi

git submodule update --init --recursive --remote

# Create venv if needed
if [ ! -f ".venv/bin/activate" ]; then
  python3 -m venv .venv
fi

# Activate and bootstrap pip inside the venv (no system pip required)
# shellcheck disable=SC1091
. .venv/bin/activate

python -m ensurepip --upgrade >/dev/null 2>&1 || true
python -m pip -q install --upgrade pip setuptools wheel

if [ -f "requirements.txt" ]; then
  python -m pip -q install --upgrade -r requirements.txt
fi

exec ./main.py
