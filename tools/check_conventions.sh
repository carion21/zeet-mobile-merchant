#!/usr/bin/env bash
# tools/check_conventions.sh
#
# Anti-regression : verifie que le code suit les conventions ZEET partner.
# Fail si l'une des regles ci-dessous est violee dans lib/.
#
# Usage :
#   ./tools/check_conventions.sh              # check tout lib/
#   ./tools/check_conventions.sh --staged     # check uniquement les .dart staged
#
# A brancher en CI ou pre-commit hook (voir tools/install_hooks.sh).
#
# Regles appliquees :
#   1. Pas de HapticFeedback.* brut (utiliser ZeetHaptics.tap/success/...)
#   2. Pas de ElevatedButton/OutlinedButton/TextButton bruts (utiliser
#      ZeetButton)
#   3. Pas de Colors.white / Colors.black / Colors.grey direct (utiliser
#      les tokens du theme : scheme.surface, AppColors.*, etc.)
#   4. Pas de SnackBar / ScaffoldMessenger.showSnackBar (utiliser
#      AppToast.showSuccess/showError/...)
#   5. Pas de Navigator.push|pop direct hors navigation_service.dart
#      (utiliser Routes.* du service centralise)
#
# Exceptions : les fichiers du package zeet_ui peuvent utiliser les APIs
# bas niveau ; eux sont la source des wrappers ZEET.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

if [[ "${1:-}" == "--staged" ]]; then
  files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '^lib/.*\.dart$' || true)
else
  files=$(find lib -name '*.dart' -type f)
fi

if [[ -z "$files" ]]; then
  echo "[conventions] aucun fichier .dart a verifier"
  exit 0
fi

violations=0
red=$'\e[31m'
yellow=$'\e[33m'
reset=$'\e[0m'

# Helper : grep -nE avec exclusion des lignes commentees (#1) et exit 0 si rien.
check() {
  local rule_name="$1"
  local pattern="$2"
  local hint="$3"
  shift 3
  local exclude_files=("$@")

  local hits
  hits=$(echo "$files" | xargs grep -nE "$pattern" 2>/dev/null \
    | grep -v -E '^[^:]+:[^:]+:\s*//' \
    || true)

  # Filter out excluded files.
  for ex in "${exclude_files[@]}"; do
    hits=$(echo "$hits" | grep -v -F "$ex" || true)
  done

  if [[ -n "$hits" ]]; then
    echo "${red}✖ $rule_name${reset}"
    echo "${yellow}  → $hint${reset}"
    echo "$hits" | sed 's/^/    /'
    echo
    violations=$((violations + $(echo "$hits" | wc -l)))
  fi
}

# --- Regle 1 : HapticFeedback brut ---
check \
  "HapticFeedback brut" \
  '\bHapticFeedback\.(selectionClick|lightImpact|mediumImpact|heavyImpact|vibrate)\(' \
  "Utiliser ZeetHaptics.tap() / .success() / .warning() / .heavy() (zeet_ui)"

# --- Regle 2 : Boutons Material bruts ---
# Tolere ButtonStyle, ElevatedButton.styleFrom (utilitaires de style).
# Ne tolere pas ElevatedButton(... onPressed: ...) en construction directe.
check \
  "Bouton Material brut" \
  '\b(ElevatedButton|OutlinedButton|TextButton)\(' \
  "Utiliser ZeetButton.primary / .secondary / .ghost (zeet_ui)" \
  "lib/screens/sync_pending/index.dart" \
  "lib/screens/order_details/index.dart" # AlertDialog system - tolere

# --- Regle 3 : Colors.* direct ---
# Tolere Colors.transparent (cas legitime UI overlay).
check \
  "Couleur Material brute" \
  '\bColors\.(white|black|grey|red|green|blue|orange|yellow|purple)(\.[a-zA-Z]|[, )])' \
  "Utiliser AppColors.* / scheme.surface / ZeetColors.* / theme tokens"

# --- Regle 4 : SnackBar legacy ---
check \
  "SnackBar legacy" \
  'ScaffoldMessenger\.of\(.+\)\.showSnackBar' \
  "Utiliser AppToast.showSuccess / .showError / .showInfo (lib/core/widgets/toastification.dart)"

# --- Regle 5 : Navigator direct ---
# Exempte le navigation_service lui-meme.
check \
  "Navigator direct" \
  '\bNavigator\.(push|pop|pushNamed|pushReplacement)\(' \
  "Utiliser Routes.* (lib/services/navigation_service.dart)" \
  "lib/services/navigation_service.dart" \
  "lib/screens/sync_pending/index.dart"

# --- Verdict ---
if [[ "$violations" -gt 0 ]]; then
  echo "${red}✖ $violations violation(s) detectee(s).${reset}"
  echo "  Reference : zeet-mobile-merchant/CLAUDE.md sections IconManager,"
  echo "              Toast Notifications, et widgets zeet_ui critiques."
  exit 1
fi

echo "[conventions] ✓ aucune violation"
exit 0
