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
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
  echo -e "${RED}✗ FAIL:${NC} $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

skip() {
  echo -e "${YELLOW}- SKIP:${NC} $1"
}

# ----------------------------------------------------------------------------
# Testes
# ----------------------------------------------------------------------------

test_help() {
  if $COMMITIA --help | grep -qi "commitia"; then
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
  # Precisa de um git funcional (ex.: licença do Xcode não aceita no macOS)
  if ! git --version &>/dev/null; then
    skip "Dry-run (git indisponível neste ambiente)"
    return 0
  fi

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
# Provedores de CLIs de IA (hermético: git e CLIs falsos em diretório temporário)
# ----------------------------------------------------------------------------

# Cria git falso e CLIs falsas (respondem com ANSI + banner + mensagem)
setup_fake_env() {
  FAKE_DIR=$(mktemp -d)
  mkdir -p "$FAKE_DIR/git" "$FAKE_DIR/cli" "$FAKE_DIR/repo"

  cat > "$FAKE_DIR/git/git" << 'EOF'
#!/usr/bin/env bash
case "$*" in
  "rev-parse --is-inside-work-tree") echo true ;;
  "rev-parse --show-toplevel") echo "$FAKE_REPO" ;;
  "diff --staged --name-only") echo "src/app.sh" ;;
  "diff --staged") printf 'diff --git a/src/app.sh b/src/app.sh\n+echo novo\n' ;;
  "branch --show-current") echo "main" ;;
  *) exit 0 ;;
esac
EOF

  local cli
  for cli in cursor-agent copilot claude codex gemini; do
    cat > "$FAKE_DIR/cli/$cli" << 'EOF'
#!/usr/bin/env bash
cat > /dev/null 2>&1 || true
out=""; prev=""
for a in "$@"; do
  [ "$prev" = "-o" ] && [ "$a" != "text" ] && out="$a"
  prev="$a"
done
if [ -n "$out" ]; then
  echo "log ruidoso" >&2
  echo "feat(app): Adiciona novo recurso." > "$out"
else
  printf '\033[33mbanner\033[0m\r\n\033[1mfeat(app): Adiciona novo recurso.\033[0m\n'
fi
EOF
  done
  chmod +x "$FAKE_DIR"/git/git "$FAKE_DIR"/cli/*
  export FAKE_REPO="$FAKE_DIR/repo"
}

test_unknown_provider() {
  setup_fake_env
  cd "$FAKE_DIR/repo"
  if PATH="$FAKE_DIR/git:$PATH" $COMMITIA -d --provider inexistente 2>&1 | grep -q "Provedor de IA desconhecido"; then
    pass "Provedor desconhecido é rejeitado"
  else
    fail "Provedor desconhecido não é rejeitado"
  fi
  cd - > /dev/null
  rm -rf "$FAKE_DIR"
}

test_cli_provider_missing_binary() {
  setup_fake_env
  cd "$FAKE_DIR/repo"
  local provider
  for provider in cursor copilot claude codex gemini-cli; do
    # PATH restrito: só o git falso e utilitários do sistema (sem as CLIs de IA)
    if PATH="$FAKE_DIR/git:/usr/bin:/bin" /bin/bash "$COMMITIA" -d --provider "$provider" 2>&1 | grep -q "não encontrado"; then
      pass "Provedor $provider reporta binário ausente"
    else
      fail "Provedor $provider não reporta binário ausente"
    fi
  done
  cd - > /dev/null
  rm -rf "$FAKE_DIR"
}

test_cli_provider_generates_message() {
  setup_fake_env
  cd "$FAKE_DIR/repo"
  local provider out
  for provider in cursor copilot claude codex gemini-cli; do
    out=$(PATH="$FAKE_DIR/git:$FAKE_DIR/cli:$PATH" $COMMITIA -d --provider "$provider" 2>&1 || true)
    # Remove ANSI e confere a mensagem (sem ponto final, descrição em minúscula)
    if echo "$out" | perl -pe 's/\e\[[0-9;]*m//g' | grep -qx "  feat(app): adiciona novo recurso"; then
      pass "Provedor $provider gera mensagem limpa (ANSI/banner removidos)"
    else
      fail "Provedor $provider não gerou a mensagem esperada"
    fi
  done
  cd - > /dev/null
  rm -rf "$FAKE_DIR"
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
test_unknown_provider
test_cli_provider_missing_binary
test_cli_provider_generates_message

echo ""
echo "====================================="
echo -e "  Resultados: ${GREEN}$TESTS_PASSED passou${NC}, ${RED}$TESTS_FAILED falhou${NC}"
echo "====================================="
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
  exit 1
fi


