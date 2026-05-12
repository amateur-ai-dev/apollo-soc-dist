#!/usr/bin/env bash
set -euo pipefail

# Apollo SOC — Bootstrap Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/amateur-ai-dev/apollo-soc-dist/main/bootstrap.sh | bash

REPO="amateur-ai-dev/apollo-soc"
VERSION="${APOLLO_VERSION:-latest}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
DIM='\033[0;90m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "${CYAN}  $1${RESET}"; }
ok()    { echo -e "${GREEN}  ✓ $1${RESET}"; }
warn()  { echo -e "${RED}  ✗ $1${RESET}"; }

echo -e "\n${BOLD}  ◈ APOLLO SOC — Installer${RESET}\n"

# --- Check gh CLI ---
if ! command -v gh &>/dev/null; then
  warn "GitHub CLI (gh) required. Install: https://cli.github.com"
  exit 1
fi

if ! gh auth status &>/dev/null 2>&1; then
  warn "Not authenticated. Run: gh auth login"
  exit 1
fi
ok "GitHub CLI authenticated"

# --- Check repo access ---
if ! gh repo view "$REPO" --json name &>/dev/null 2>&1; then
  warn "No access to $REPO. Request collaborator access from the repo owner."
  exit 1
fi
ok "Repo access verified"

# --- Check/install uv ---
if ! command -v uv &>/dev/null; then
  info "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
ok "uv $(uv --version 2>/dev/null | head -1)"

# --- Ensure Python 3.12+ via uv ---
PY_OK=false
if command -v python3 &>/dev/null; then
  PY_MAJOR=$(python3 -c 'import sys; print(sys.version_info.major)')
  PY_MINOR=$(python3 -c 'import sys; print(sys.version_info.minor)')
  if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 12 ]; then
    PY_OK=true
  fi
fi

if [ "$PY_OK" = false ]; then
  info "Installing Python 3.12 via uv..."
  uv python install 3.12
  UV_PY=$(uv python find 3.12 2>/dev/null || true)
  if [ -n "$UV_PY" ]; then
    export UV_PYTHON="$UV_PY"
    ok "Python 3.12 installed via uv ($UV_PY)"
  else
    warn "Could not install Python 3.12. Install manually."
    exit 1
  fi
else
  PY_VERSION="${PY_MAJOR}.${PY_MINOR}"
  ok "Python $PY_VERSION"
fi

# --- Download wheel from private release ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

info "Downloading apollo-soc from GitHub Release ($VERSION)..."
if [ "$VERSION" = "latest" ]; then
  gh release download --repo "$REPO" --pattern "*.whl" --dir "$TMPDIR" 2>/dev/null
else
  gh release download "$VERSION" --repo "$REPO" --pattern "*.whl" --dir "$TMPDIR" 2>/dev/null
fi

WHL=$(find "$TMPDIR" -name "*.whl" | head -1)
if [ -z "$WHL" ]; then
  warn "No wheel found in release. Check repo releases."
  exit 1
fi
ok "Downloaded $(basename "$WHL")"

# --- Create venv + install ---
APOLLO_HOME="${APOLLO_HOME:-$HOME/.apollo-soc}"
info "Creating virtual environment at $APOLLO_HOME..."

PY_ARG=""
if [ -n "${UV_PYTHON:-}" ]; then
  PY_ARG="--python $UV_PYTHON"
fi
uv venv $PY_ARG "$APOLLO_HOME/venv" --quiet 2>/dev/null
ok "venv created"

info "Installing apollo-soc..."
VIRTUAL_ENV="$APOLLO_HOME/venv"
uv pip install --python "$APOLLO_HOME/venv/bin/python" "$WHL[scanners]" --quiet 2>/dev/null \
  || uv pip install --python "$APOLLO_HOME/venv/bin/python" "$WHL" --quiet
ok "apollo-soc installed"

# --- Add to PATH ---
BINDIR="$APOLLO_HOME/venv/bin"
if [[ ":$PATH:" != *":$BINDIR:"* ]]; then
  export PATH="$BINDIR:$PATH"
fi

SHELL_RC=""
if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -n "${BASH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "bash" ]; then
  SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ]; then
  PATH_LINE="export PATH=\"$BINDIR:\$PATH\""
  if ! grep -qF "$BINDIR" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# Apollo SOC" >> "$SHELL_RC"
    echo "$PATH_LINE" >> "$SHELL_RC"
    ok "Added to $SHELL_RC (restart shell or: source $SHELL_RC)"
  fi
fi

# --- Install binary scanners ---
install_binary() {
  local name="$1" brew_name="$2" hint="$3"
  if command -v "$name" &>/dev/null; then
    ok "$name available"
    return 0
  fi
  if command -v brew &>/dev/null; then
    info "Installing $name..."
    if brew install "$brew_name" &>/dev/null 2>&1; then
      ok "$name installed"
      return 0
    fi
  fi
  warn "$name not found. Install: $hint"
  return 1
}

echo ""
info "Installing scanners..."

install_binary trivy trivy "brew install trivy" || true
install_binary grype grype "brew install grype" || true
install_binary osv-scanner osv-scanner "brew install osv-scanner" || true
install_binary gitleaks gitleaks "brew install gitleaks" || true
install_binary trufflehog trufflehog "brew install trufflehog" || true
install_binary nuclei nuclei "brew install nuclei" || true
install_binary kubescape kubescape "brew install kubescape" || true
install_binary kube-bench kube-bench "brew install kube-bench" || true
install_binary syft syft "brew install syft" || true
install_binary cosign cosign "brew install cosign" || true

# Checkov/Prowler installed separately (networkx conflict with llama-index)
info "Installing checkov + prowler..."
VENV_PY="$APOLLO_HOME/venv/bin/python"
uv pip install --python "$VENV_PY" "checkov>=3.2" --quiet 2>/dev/null && ok "checkov installed" || warn "checkov failed (networkx conflict — install in separate venv)"
uv pip install --python "$VENV_PY" "prowler>=4.0" --quiet 2>/dev/null && ok "prowler installed" || warn "prowler failed (install manually: pip install prowler)"

# --- Scanner summary ---
echo ""
echo -e "${BOLD}  Scanner Status:${RESET}"
echo -e "${DIM}  ─────────────────────────────────────${RESET}"

SCANNERS=("semgrep:SAST" "bandit:Python" "checkov:IaC" "trivy:Vuln" "grype:Vuln" "osv-scanner:OSV" "gitleaks:Secrets" "trufflehog:Secrets" "nuclei:DAST" "kubescape:K8s" "kube-bench:CIS" "syft:SBOM" "cosign:Signing" "prowler:Cloud")

INSTALLED=0
MISSING=0
for entry in "${SCANNERS[@]}"; do
  name="${entry%%:*}"
  desc="${entry##*:}"
  if command -v "$name" &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} ${name} ${DIM}(${desc})${RESET}"
    ((INSTALLED++))
  else
    echo -e "  ${RED}✗${RESET} ${name} ${DIM}(${desc})${RESET}"
    ((MISSING++))
  fi
done

echo -e "${DIM}  ─────────────────────────────────────${RESET}"
echo -e "  ${GREEN}${INSTALLED} installed${RESET}  ${RED}${MISSING} missing${RESET}"

# --- Done ---
echo ""
echo -e "${BOLD}  ◈ Apollo SOC ready${RESET}"
echo ""
echo -e "  ${CYAN}Dashboard:${RESET}  apollo serve"
echo -e "  ${CYAN}Scan:${RESET}       apollo scan /path/to/project"
echo -e "  ${CYAN}Version:${RESET}    apollo --version"
echo ""
