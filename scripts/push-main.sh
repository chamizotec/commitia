#!/usr/bin/env bash
#
# Push na main e em seguida faz pull para trazer o commit de bump de versão
# (gerado pelo GitHub Actions ao fazer push na main).
#
# Uso: ./scripts/push-main.sh [argumentos extras para git push]
# Ex.: ./scripts/push-main.sh
#      ./scripts/push-main.sh --force
#

set -e

BRANCH=$(git branch --show-current 2>/dev/null || true)

if [ -z "$BRANCH" ]; then
  echo "Não está em um repositório Git."
  exit 1
fi

if [ "$BRANCH" != "main" ]; then
  echo "Você está na branch '$BRANCH'. Faça checkout em main ou use: git push origin main && git pull"
  exit 1
fi

echo "→ git push origin main $*"
git push origin main "$@"

echo ""
echo "→ git pull (trazendo bump de versão do CI, se houver)"
git pull

echo ""
echo "✓ Push e pull concluídos."
