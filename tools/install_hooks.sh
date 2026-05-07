#!/usr/bin/env bash
# tools/install_hooks.sh
#
# Installe le pre-commit hook qui execute check_conventions.sh sur les
# fichiers .dart staged. Prevent les nouvelles violations sans bloquer
# le legacy (mode --staged).
#
# Usage : ./tools/install_hooks.sh

set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

if [[ ! -d .git ]]; then
  echo "✖ pas un depot git (cwd=$(pwd))"
  exit 1
fi

hook=".git/hooks/pre-commit"
cat > "$hook" <<'EOF'
#!/usr/bin/env bash
# Pre-commit ZEET partner — verifie les conventions sur les fichiers staged.
exec ./tools/check_conventions.sh --staged
EOF
chmod +x "$hook"

echo "✓ pre-commit hook installe (.git/hooks/pre-commit)"
echo "  Pour bypass exceptionnellement : git commit --no-verify"
