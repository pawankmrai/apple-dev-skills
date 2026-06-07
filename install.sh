#!/usr/bin/env bash
# install.sh — Apple Dev Skills installer
# Usage:
#   ./install.sh              # download all skills to ./skills/
#   ./install.sh --cowork     # also install as a Cowork skill
#   ./install.sh --help

set -euo pipefail

REPO="pawankmrai/apple-dev-skills"
RAW="https://raw.githubusercontent.com/${REPO}/main"
GITHUB="https://github.com/${REPO}"
SKILLS_DIR="./apple-dev-skills"
COWORK_PLUGINS_DIR="${HOME}/Library/Application Support/Claude/plugins"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'

usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --cowork      Also install as a Cowork skill (macOS only)"
  echo "  --dir PATH    Install skills to PATH (default: ./apple-dev-skills)"
  echo "  --help        Show this help"
  echo ""
  echo "Examples:"
  echo "  curl -fsSL ${GITHUB}/raw/main/install.sh | bash"
  echo "  curl -fsSL ${GITHUB}/raw/main/install.sh | bash -s -- --cowork"
}

INSTALL_COWORK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cowork) INSTALL_COWORK=true; shift ;;
    --dir) SKILLS_DIR="$2"; shift 2 ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

echo -e "${CYAN}Apple Dev Skills Installer${RESET}"
echo "Repo: ${GITHUB}"
echo ""

# ── Step 1: Fetch skill list from README ────────────────────────────────────
echo -e "${YELLOW}Fetching skill index...${RESET}"
README=$(curl -fsSL "${RAW}/README.md")
SLUGS=$(echo "$README" | grep -oE '\[([a-z0-9-]+)\]\(skills/[a-z0-9-]+\.md\)' \
        | grep -oE 'skills/[a-z0-9-]+\.md' | sed 's|skills/||;s|\.md||')
SKILL_COUNT=$(echo "$SLUGS" | wc -l | tr -d ' ')
echo "Found ${SKILL_COUNT} skills."
echo ""

# ── Step 2: Download skills ──────────────────────────────────────────────────
mkdir -p "${SKILLS_DIR}/skills"

echo -e "${YELLOW}Downloading skills to ${SKILLS_DIR}/skills/ ...${RESET}"
DOWNLOADED=0
for slug in $SLUGS; do
  url="${RAW}/skills/${slug}.md"
  dest="${SKILLS_DIR}/skills/${slug}.md"
  if curl -fsSL "$url" -o "$dest" 2>/dev/null; then
    echo "  ✓ ${slug}"
    DOWNLOADED=$((DOWNLOADED + 1))
  else
    echo "  ✗ ${slug} (download failed)"
  fi
done

# Also grab SKILL.md and README
curl -fsSL "${RAW}/SKILL.md"  -o "${SKILLS_DIR}/SKILL.md"
curl -fsSL "${RAW}/README.md" -o "${SKILLS_DIR}/README.md"

echo ""
echo -e "${GREEN}Downloaded ${DOWNLOADED}/${SKILL_COUNT} skills to ${SKILLS_DIR}/${RESET}"

# ── Step 3: Optionally install as a Cowork skill ─────────────────────────────
if $INSTALL_COWORK; then
  echo ""
  echo -e "${YELLOW}Installing as Cowork skill...${RESET}"

  if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "  Cowork skill install is macOS-only. Skipping."
  else
    SKILL_DEST="${COWORK_PLUGINS_DIR}/apple-skills"
    mkdir -p "$SKILL_DEST/skills"
    cp "${SKILLS_DIR}/SKILL.md" "$SKILL_DEST/SKILL.md"
    cp "${SKILLS_DIR}/skills/"*.md "$SKILL_DEST/skills/"
    echo -e "${GREEN}  Installed to ${SKILL_DEST}${RESET}"
    echo "  Restart Claude to activate the skill."
  fi
fi

echo ""
echo -e "${GREEN}Done!${RESET}"
echo ""
echo "To browse skills:  ls ${SKILLS_DIR}/skills/"
echo "To update later:   bash ${SKILLS_DIR}/../install.sh --dir ${SKILLS_DIR}"
