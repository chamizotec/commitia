#!/usr/bin/env bash
#
# Testes básicos para o CommitIA
#

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMITIA="$SCRIPT_DIR/../bin/commitia"

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
  echo -e "${GREEN}✓ PASS:${NC} $1"
  ((TESTS_PASSED++))
}

fail() {
  echo -e "${RED}✗ FAIL:${NC} $1"
  ((TESTS_FAILED++))
}

# ----------------------------------------------------------------------------
# Testes
# ----------------------------------------------------------------------------

test_help() {
  if $COMMITIA --help | grep -q "CommitIA"; then
    pass "Help exibe informações corretas"
  else
    fail "Help não exibe informações"
  fi
}

test_version() {
  if $COMMITIA --version | grep -q "CommitIA"; then
    pass "Version retorna versão"
  else
    fail "Version não retorna versão"
  fi
}

test_invalid_option() {
  if $COMMITIA --invalid-option 2>&1 | grep -q "Opção desconhecida"; then
    pass "Opção inválida é tratada corretamente"
  else
    fail "Opção inválida não é tratada"
  fi
}

test_not_git_repo() {
  local temp_dir
  temp_dir=$(mktemp -d)
  cd "$temp_dir"
  
  if $COMMITIA 2>&1 | grep -q "repositório Git"; then
    pass "Detecta quando não está em repo Git"
  else
    fail "Não detecta ausência de repo Git"
  fi
  
  cd - > /dev/null
  rm -rf "$temp_dir"
}

test_dry_run() {
  # Cria um repo temporário
  local temp_dir
  temp_dir=$(mktemp -d)
  cd "$temp_dir"
  git init > /dev/null 2>&1
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "test" > test.txt
  git add test.txt
  
  # Testa dry-run (vai falhar se não tiver provedor de IA, mas é ok)
  if $COMMITIA --dry-run 2>&1 | grep -qE "(dry-run|não encontrado)"; then
    pass "Dry-run funciona ou reporta dependência"
  else
    fail "Dry-run não funciona como esperado"
  fi
  
  cd - > /dev/null
  rm -rf "$temp_dir"
}

# ----------------------------------------------------------------------------
# Execução
# ----------------------------------------------------------------------------

echo ""
echo "====================================="
echo "  Testes do CommitIA"
echo "====================================="
echo ""

test_help
test_version
test_invalid_option
test_not_git_repo
test_dry_run

echo ""
echo "====================================="
echo -e "  Resultados: ${GREEN}$TESTS_PASSED passou${NC}, ${RED}$TESTS_FAILED falhou${NC}"
echo "====================================="
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
  exit 1
fi

