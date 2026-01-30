#!/usr/bin/env bash
#
# Push na main, aguarda o CI rodar e faz pull para trazer o commit de bump de versão
# (gerado pelo GitHub Actions ao fazer push na main).
#
# Uso: ./scripts/push-main.sh [argumentos extras para git push]
#      PUSHMAIN_DELAY=15 ./scripts/push-main.sh   # delay em segundos (padrão: 10)
# Ex.: ./scripts/push-main.sh
#      ./scripts/push-main.sh --force
#

set -e

DELAY="${PUSHMAIN_DELAY:-10}"

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
echo "→ Aguardando CI rodar (${DELAY}s)..."
sleep "$DELAY"

echo "→ git pull (trazendo bump de versão do CI, se houver)"
git pull

echo ""
echo "✓ Push e pull concluídos."
