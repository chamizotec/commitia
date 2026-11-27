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

# Os testes nunca consultam a rede real: a checagem de nova versão fica desligada
# por padrão (os testes dela a ligam explicitamente, com origem local/curl falso)
export COMMITIA_SKIP_UPDATE_CHECK=true
unset COMMITIA_UPDATED_REEXEC COMMITIA_REPO_RAW_URL COMMITIA_TEST_FORCE_TTY

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

# Hash de stdin (shasum no macOS/Linux; sha1sum no Git Bash/Windows)
hash_stdin() {
  if command -v shasum &>/dev/null; then
    shasum
  else
    sha1sum
  fi
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
  
  # Testa dry-run de forma hermética: amp falso no PATH e HOME isolado
  # (um amp real instalado, mas sem login, faria o teste depender do ambiente)
  mkdir -p "$temp_dir/.fakebin" "$temp_dir/.fakehome"
  printf '#!/usr/bin/env bash\ncat > /dev/null\necho "feat(app): adiciona teste"\n' > "$temp_dir/.fakebin/amp"
  chmod +x "$temp_dir/.fakebin/amp"
  if HOME="$temp_dir/.fakehome" PATH="$temp_dir/.fakebin:$PATH" $COMMITIA --dry-run 2>&1 | grep -qE "(dry-run|não encontrado)"; then
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

# Texto de '--help' de uma CLI falsa atualizada: lista todas as flags que o commitia usa.
# Se o 2º argumento (flag) for informado, remove essa flag do texto (simula versão antiga).
# O cursor-agent lista também --model, para provar que --mode não casa com --model.
fake_help_text() {
  fake_help_full "$1" | perl -pe "s/(?<![\\w-])\\Q${2:-__nenhuma__}\\E(?![\\w-])//g"
}

fake_help_full() {
  case "$1" in
    cursor-agent)
      echo "Usage: agent [options]"
      echo "  -p, --print              Print responses"
      echo "  --output-format <format> text | json"
      echo "  --mode <mode>            plan | ask"
      echo "  --model <model>          Model to use"
      ;;
    copilot)
      echo "Usage: copilot [OPTIONS]"
      echo "  -p, --prompt <text>"
      echo "  -s, --silent"
      echo "  --no-color --no-ask-user --no-custom-instructions"
      echo "  --no-auto-update --disable-builtin-mcps"
      echo "  --deny-tool [<tools>...]"
      ;;
    claude)
      echo "Usage: claude [options]"
      echo "  -p, --print"
      echo "  --tools <tools...>  --disable-slash-commands  --strict-mcp-config"
      echo "  --no-session-persistence"
      echo "  --output-format <format>"
      ;;
    codex)
      echo "Usage: codex exec [OPTIONS]"
      echo "  --skip-git-repo-check  --ephemeral  -s, --sandbox <MODE>"
      echo "  --color <COLOR>  -o, --output-last-message <FILE>"
      ;;
    gemini)
      echo "Usage: gemini [options]"
      echo "  -p, --prompt  --approval-mode  --skip-trust  -o, --output-format"
      ;;
  esac
}

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
    # --help da CLI falsa "atualizada" (arquivo ao lado do executável)
    fake_help_text "$cli" > "$FAKE_DIR/cli/$cli.help"
    # --help da versão nova (usado pelo "update" falso)
    fake_help_text "$cli" > "$FAKE_DIR/cli/$cli.help.new"
    cat > "$FAKE_DIR/cli/$cli" << 'EOF'
#!/usr/bin/env bash
# 'update' (cursor-agent update): "atualiza" trocando o --help pelo da versão nova
if [ "$1" = "update" ]; then
  [ -n "$FAKE_UPDATE_FAIL" ] && exit 1
  echo "$*" >> "$0.updated"
  [ -n "$FAKE_UPDATE_NOFIX" ] || cp "$0.help.new" "$0.help"
  exit 0
fi
# --version / --help não consomem stdin nem geram mensagem
case "$*" in
  *--version*) echo "1.2.3 (fake)"; exit 0 ;;
  *--help*) cat "$0.help"; exit 0 ;;
esac
cat > /dev/null 2>&1 || true
# Simula uma CLI antiga que rejeita flags novas em tempo de execução
if [ -n "$FAKE_RUNTIME_ERROR" ]; then
  echo "error: unknown option '--mode' (Did you mean --model?)" >&2
  exit 1
fi
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
  # npm falso: "npm install -g <pacote>@latest" atualiza a CLI falsa correspondente
  cat > "$FAKE_DIR/cli/npm" << 'EOF3'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_NPM_LOG"
[ -n "$FAKE_UPDATE_FAIL" ] && exit 1
case "$*" in
  "install -g @github/copilot@latest") bin=copilot ;;
  "install -g @anthropic-ai/claude-code@latest") bin=claude ;;
  "install -g @openai/codex@latest") bin=codex ;;
  "install -g @google/gemini-cli@latest") bin=gemini ;;
  *) exit 1 ;;
esac
[ -n "$FAKE_UPDATE_NOFIX" ] || cp "$(dirname "$0")/$bin.help.new" "$(dirname "$0")/$bin.help"
EOF3
  chmod +x "$FAKE_DIR"/git/git "$FAKE_DIR"/cli/*
  export FAKE_REPO="$FAKE_DIR/repo"
  export FAKE_NPM_LOG="$FAKE_DIR/npm.log"
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
# Arquivos grandes (hermético: git real em repositórios temporários + CLI falsa)
#
# A CLI falsa "claude" grava cada prompt recebido em $LG_DIR/out/prompt-N.txt e
# responde com uma mensagem válida. Falha (exit 1) quando o prompt casa com
# FAKE_FAIL_MATCH e também com FAKE_FAIL_MATCH2 (padrão: qualquer um).
# ----------------------------------------------------------------------------

# Cria o ambiente: repo com um commit inicial, HOME isolado e CLI falsa
setup_large_env() {
  LG_DIR=$(mktemp -d)
  mkdir -p "$LG_DIR/bin" "$LG_DIR/home" "$LG_DIR/out" "$LG_DIR/repo"
  LG_REPO="$LG_DIR/repo"

  fake_help_text claude > "$LG_DIR/bin/claude.help"
  cat > "$LG_DIR/bin/claude" << 'EOF2'
#!/usr/bin/env bash
# --version / --help (validação de versão): não gravam prompt
case "$*" in
  *--version*) echo "1.2.3 (fake)"; exit 0 ;;
  *--help*) cat "$0.help"; exit 0 ;;
esac
prompt=$(cat)
n=$(ls "$FAKE_OUT" 2>/dev/null | wc -l | tr -d ' ')
printf '%s' "$prompt" > "$FAKE_OUT/prompt-$((n + 1)).txt"
# Simula CLI antiga: rejeita a flag em tempo de execução (prompt casando com FAKE_RUNTIME_ERROR)
if [ -n "$FAKE_RUNTIME_ERROR" ] && printf '%s' "$prompt" | grep -qE "$FAKE_RUNTIME_ERROR"; then
  echo "error: unknown option '--tools' (Did you mean --tool?)" >&2
  exit 1
fi
if [ -n "$FAKE_FAIL_MATCH" ] \
  && printf '%s' "$prompt" | grep -qE "$FAKE_FAIL_MATCH" \
  && printf '%s' "$prompt" | grep -qE "${FAKE_FAIL_MATCH2:-.}"; then
  echo "erro simulado da IA" >&2
  exit 1
fi
echo "feat(app): Adiciona recurso."
EOF2
  chmod +x "$LG_DIR/bin/claude"

  git -C "$LG_REPO" init -q
  git -C "$LG_REPO" config user.email "test@test.com"
  git -C "$LG_REPO" config user.name "Test"
  git -C "$LG_REPO" config commit.gpgsign false
  git -C "$LG_REPO" config core.hooksPath "$LG_REPO/.git/hooks"
  echo "inicio" > "$LG_REPO/README.md"
  git -C "$LG_REPO" add README.md
  git -C "$LG_REPO" commit -q -m "chore: init"
}

teardown_large_env() {
  rm -rf "$LG_DIR"
}

# Executa o commitia no repo temporário (saída sem ANSI em $LG_OUT, código em $LG_RC).
# Argumentos iniciais no formato VAR=valor viram variáveis de ambiente apenas dessa execução
# (evita vazar variáveis entre testes); os demais vão para o commitia.
lg_commitia() {
  local -a envs=()
  while [ $# -gt 0 ]; do
    case "$1" in
      [A-Z_]*=*) envs+=("$1"); shift ;;
      *) break ;;
    esac
  done
  LG_OUT=$( (cd "$LG_REPO" && { [ -z "${LG_STDIN+x}" ] || exec < <(printf '%b' "$LG_STDIN"); } && env -u FAKE_FAIL_MATCH -u FAKE_FAIL_MATCH2 -u FAKE_RUNTIME_ERROR -u COMMITIA_LARGE_FILES -u COMMITIA_LARGE_FILE_LINES \
    -u COMMITIA_LARGE_FILE_BYTES -u COMMITIA_LARGE_FILE_PATTERNS \
    HOME="$LG_DIR/home" PATH="$LG_DIR/bin:$PATH" FAKE_OUT="$LG_DIR/out" \
    ${envs[@]+"${envs[@]}"} "${LG_COMMITIA:-$COMMITIA}" --provider claude "$@" 2>&1; echo "RC=$?") | perl -pe 's/\e\[[0-9;]*m//g')
  LG_RC=$(echo "$LG_OUT" | sed -n 's/^RC=//p')
  LG_OUT=$(echo "$LG_OUT" | sed '/^RC=[0-9]*$/d')
}

lg_git() { git -C "$LG_REPO" "$@"; }
lg_count() { lg_git rev-list --count HEAD; }
# Arquivos do commit N (0 = HEAD, 1 = HEAD~1...), ordenados e em uma linha
lg_files() { lg_git show --name-only --format= "HEAD~$1" | sort | tr '\n' ' ' | sed 's/ $//'; }
lg_staged() { lg_git diff --staged --name-only | sort | tr '\n' ' ' | sed 's/ $//'; }
lg_prompt() { cat "$LG_DIR/out/prompt-$1.txt" 2>/dev/null; }
lg_nprompts() { ls "$LG_DIR/out" | wc -l | tr -d ' '; }

# Gera um arquivo "lockfile" com N linhas
lg_make_lock() {
  local file="$1" n="${2:-30}" i
  for i in $(seq 1 "$n"); do echo "pacote$i: 1.0.$i"; done > "$LG_REPO/$file"
}

expect_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (obtido: '$2', esperado: '$3')"; fi
}
expect_contains() {
  if printf '%s' "$2" | grep -qF -- "$3"; then pass "$1"; else fail "$1 (não contém: '$3')"; fi
}
expect_not_contains() {
  if printf '%s' "$2" | grep -qF -- "$3"; then fail "$1 (contém indevidamente: '$3')"; else pass "$1"; fi
}

large_tests_available() {
  if ! git --version &>/dev/null; then
    skip "Arquivos grandes (git indisponível neste ambiente)"
    return 1
  fi
  return 0
}

test_large_none() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_commitia
  expect_eq "Sem arquivos grandes: um único commit" "$(lg_count)" "2"
  expect_not_contains "Sem arquivos grandes: não menciona separação" "$LG_OUT" "Arquivos grandes detectados"
  teardown_large_env
}

test_large_split_lockfile() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock pnpm-lock.yaml 30
  lg_commitia
  expect_eq "Lockfile + pequeno: 2 commits novos" "$(lg_count)" "3"
  expect_eq "Lockfile + pequeno: primeiro commit só com o pequeno" "$(lg_files 1)" "app.sh"
  expect_eq "Lockfile + pequeno: segundo commit só com o lockfile" "$(lg_files 0)" "pnpm-lock.yaml"
  expect_contains "Lockfile + pequeno: avisa arquivos grandes" "$LG_OUT" "Arquivos grandes detectados"
  expect_eq "Lockfile + pequeno: working tree limpa" "$(lg_git status --porcelain)" ""
  teardown_large_env
}

test_large_only_lockfiles() {
  large_tests_available || return 0
  setup_large_env
  lg_make_lock package-lock.json 10
  lg_make_lock yarn.lock 10
  lg_commitia
  expect_eq "Só lockfiles: um commit por arquivo" "$(lg_count)" "3"
  expect_eq "Só lockfiles: commit 1" "$(lg_files 1)" "package-lock.json"
  expect_eq "Só lockfiles: commit 2" "$(lg_files 0)" "yarn.lock"
  teardown_large_env
}

test_large_single_lockfile() {
  large_tests_available || return 0
  setup_large_env
  lg_make_lock composer.lock 10
  lg_commitia
  expect_eq "Um único lockfile: commit normal" "$(lg_count)" "2"
  expect_eq "Um único lockfile: conteúdo do commit" "$(lg_files 0)" "composer.lock"
  teardown_large_env
}

test_large_by_lines() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock dados.txt 30
  lg_commitia COMMITIA_LARGE_FILE_LINES=20
  expect_eq "Limite de linhas: arquivo grande em commit separado" "$(lg_files 0)" "dados.txt"
  expect_eq "Limite de linhas: pequeno primeiro" "$(lg_files 1)" "app.sh"
  expect_contains "Limite de linhas: motivo informado" "$LG_OUT" "30 linhas alteradas"
  teardown_large_env

  # Abaixo do limite: nada é separado
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock dados.txt 30
  lg_commitia COMMITIA_LARGE_FILE_LINES=100
  expect_eq "Abaixo do limite de linhas: commit único" "$(lg_count)" "2"
  teardown_large_env
}

test_large_by_bytes_diff() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  # 3 linhas muito longas: poucas linhas, mas diff grande em bytes
  local i
  for i in 1 2 3; do head -c 2000 /dev/zero | tr '\0' 'x'; echo; done > "$LG_REPO/minificado.js"
  lg_commitia COMMITIA_LARGE_FILE_BYTES=1500
  expect_eq "Limite de bytes do diff: arquivo grande separado" "$(lg_files 0)" "minificado.js"
  expect_contains "Limite de bytes do diff: motivo informado" "$LG_OUT" "bytes"
  teardown_large_env
}

test_large_binary() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  head -c 5000 /dev/urandom > "$LG_REPO/imagem.bin"
  printf '\000\001\002' > "$LG_REPO/pequeno.bin"
  lg_commitia COMMITIA_LARGE_FILE_BYTES=1000
  expect_eq "Binário grande: commit próprio" "$(lg_files 0)" "imagem.bin"
  expect_eq "Binário pequeno segue com os arquivos pequenos" "$(lg_files 1)" "app.sh pequeno.bin"
  expect_contains "Binário grande: avisa que é binário" "$LG_OUT" "arquivo binário"
  # Só o resumo é enviado para o binário (nenhum diff)
  expect_contains "Binário grande: prompt com resumo" "$(lg_prompt 2)" "arquivo binário"
  expect_not_contains "Binário grande: sem diff no prompt" "$(lg_prompt 2)" "Binary files"
  teardown_large_env
}

test_large_fallback_summary() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock pnpm-lock.yaml 30
  # A IA falha quando recebe o diff completo do lockfile; aceita o resumo
  lg_commitia FAKE_FAIL_MATCH='^Diff:' FAKE_FAIL_MATCH2='pnpm-lock'
  expect_eq "Fallback: 2 commits novos" "$(lg_count)" "3"
  expect_eq "Fallback: lockfile commitado" "$(lg_files 0)" "pnpm-lock.yaml"
  expect_contains "Fallback: informa uso do fallback" "$LG_OUT" "Mensagem gerada pelo fallback"
  expect_eq "Fallback: mensagem veio da IA (resumo)" "$(lg_git log -1 --format=%s)" "feat(app): adiciona recurso"
  local p
  p=$(lg_prompt 3)
  expect_contains "Fallback: prompt com o nome do arquivo" "$p" "pnpm-lock.yaml"
  expect_contains "Fallback: prompt com as linhas alteradas" "$p" "+30 -0"
  expect_contains "Fallback: prompt com cabeçalho do hunk" "$p" "@@ -0,0 +1,30 @@"
  expect_contains "Fallback: último commit da sessão (pequenos)" "$p" "Último commit feito nesta sessão"
  expect_contains "Fallback: assunto do commit da sessão" "$p" "feat(app): adiciona recurso"
  expect_not_contains "Fallback: sem o diff completo" "$p" "diff --git"
  expect_eq "Fallback: log da falha intermediária mantido" "$(ls "$LG_REPO/.commitia/logs" | wc -l | tr -d ' ')" "1"
  teardown_large_env
}

test_large_no_session_commit_goes_to_last_resort() {
  large_tests_available || return 0
  setup_large_env
  lg_make_lock pnpm-lock.yaml 12
  # Nenhum commit foi criado nesta sessão: não usa o commit da branch, vai direto ao último recurso
  lg_commitia FAKE_FAIL_MATCH='^Diff:' FAKE_FAIL_MATCH2='pnpm-lock'
  expect_eq "Sem commit na sessão: mensagem de último recurso" "$(lg_git log -1 --format=%s)" "chore(deps): atualiza pnpm-lock.yaml"
  expect_eq "Sem commit na sessão: IA chamada só uma vez (sem fallback com resumo)" "$(lg_nprompts)" "1"
  expect_not_contains "Sem commit na sessão: não usa o último commit da branch" "$(lg_prompt 1)" "Último commit da branch"
  expect_not_contains "Sem commit na sessão: commit da branch fora do contexto" "$(lg_prompt 1)" "chore: init"
  expect_contains "Sem commit na sessão: informa o caminho direto" "$LG_OUT" "Nenhum commit nesta sessão"
  expect_contains "Sem commit na sessão: avisa último recurso" "$LG_OUT" "mensagem padrão de último recurso"
  expect_eq "Sem commit na sessão: 1 log de falha" "$(ls "$LG_REPO/.commitia/logs" | wc -l | tr -d ' ')" "1"
  teardown_large_env
}

test_large_last_resort() {
  large_tests_available || return 0

  # Lockfile: chore(deps)
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock pnpm-lock.yaml 12
  lg_commitia FAKE_FAIL_MATCH='.' FAKE_FAIL_MATCH2='pnpm-lock'
  expect_eq "Último recurso: lockfile usa chore(deps)" "$(lg_git log -1 --format=%s)" "chore(deps): atualiza pnpm-lock.yaml"
  expect_eq "Último recurso: pequenos commitados normalmente" "$(lg_git log -2 --format=%s | tail -1)" "feat(app): adiciona recurso"
  expect_contains "Último recurso: avisa o usuário" "$LG_OUT" "mensagem padrão de último recurso"
  expect_eq "Último recurso: 2 logs de falha mantidos" "$(ls "$LG_REPO/.commitia/logs" | wc -l | tr -d ' ')" "2"
  teardown_large_env

  # Task ID da branch tem prioridade sobre "deps"
  setup_large_env
  lg_git checkout -q -b feature/ENP-123-teste
  lg_make_lock yarn.lock 12
  lg_commitia FAKE_FAIL_MATCH='.'
  expect_eq "Último recurso: respeita o task id da branch" "$(lg_git log -1 --format=%s)" "chore(ENP-123): atualiza yarn.lock"
  teardown_large_env

  # Escopo e tipo forçados
  setup_large_env
  lg_make_lock Cargo.lock 12
  lg_commitia FAKE_FAIL_MATCH='.' -s api -t build
  expect_eq "Último recurso: respeita --scope e --type" "$(lg_git log -1 --format=%s)" "build(api): atualiza Cargo.lock"
  teardown_large_env

  # Arquivo grande que não é lockfile: escopo pelo diretório
  setup_large_env
  mkdir -p "$LG_REPO/docs"
  lg_make_lock docs/enorme.txt 30
  lg_commitia FAKE_FAIL_MATCH='.' COMMITIA_LARGE_FILE_LINES=20
  expect_eq "Último recurso: arquivo grande comum" "$(lg_git log -1 --format=%s)" "chore(docs): atualiza enorme.txt"
  teardown_large_env
}

test_large_dry_run() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock pnpm-lock.yaml 30
  lg_git add -A
  local head_before staged_before
  head_before=$(lg_git rev-parse HEAD)
  staged_before=$(lg_git diff --staged | hash_stdin)
  lg_commitia FAKE_FAIL_MATCH='^Diff:' FAKE_FAIL_MATCH2='pnpm-lock' --dry-run
  expect_eq "Dry-run: nenhum commit criado" "$(lg_git rev-parse HEAD)" "$head_before"
  expect_eq "Dry-run: stage intacto" "$(lg_git diff --staged | hash_stdin)" "$staged_before"
  expect_eq "Dry-run: ambos continuam no stage" "$(lg_staged)" "app.sh pnpm-lock.yaml"
  expect_contains "Dry-run: mostra o plano" "$LG_OUT" "Arquivos grandes detectados"
  expect_contains "Dry-run: mostra que usou fallback" "$LG_OUT" "Mensagem gerada pelo fallback"
  expect_contains "Dry-run: contexto simulado do commit anterior" "$(lg_prompt 3)" "simulado"
  teardown_large_env
}

test_large_small_failure_restores() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock pnpm-lock.yaml 30
  lg_git add -A
  local blob head_before
  blob=$(lg_git rev-parse :pnpm-lock.yaml)
  head_before=$(lg_git rev-parse HEAD)
  # Depois do stage, o arquivo muda no disco (o que foi staged é que vale)
  echo "extra: 1" >> "$LG_REPO/pnpm-lock.yaml"
  # A IA falha para o grupo dos pequenos (sem fallback para eles)
  lg_commitia FAKE_FAIL_MATCH='.' FAKE_FAIL_MATCH2='app.sh'
  expect_eq "Falha nos pequenos: sai com erro" "$LG_RC" "1"
  expect_eq "Falha nos pequenos: nenhum commit criado" "$(lg_git rev-parse HEAD)" "$head_before"
  expect_eq "Falha nos pequenos: lockfile devolvido ao stage" "$(lg_staged)" "app.sh pnpm-lock.yaml"
  expect_eq "Falha nos pequenos: conteúdo staged preservado" "$(lg_git rev-parse :pnpm-lock.yaml)" "$blob"
  expect_contains "Falha nos pequenos: avisa a restauração" "$LG_OUT" "devolvidos ao stage"
  teardown_large_env
}

test_large_commit_hook_failure() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock package-lock.json 10
  lg_make_lock yarn.lock 10
  # Hook que rejeita o commit do package-lock.json
  cat > "$LG_REPO/.git/hooks/pre-commit" << 'EOF2'
#!/usr/bin/env bash
if git diff --cached --name-only | grep -q 'package-lock.json'; then
  echo "hook: rejeitado" >&2
  exit 1
fi
EOF2
  chmod +x "$LG_REPO/.git/hooks/pre-commit"
  lg_commitia
  expect_eq "Falha de hook: sai com erro" "$LG_RC" "1"
  expect_eq "Falha de hook: pequenos já commitados" "$(lg_count)" "2"
  expect_eq "Falha de hook: arquivo rejeitado e pendente continuam no stage" "$(lg_staged)" "package-lock.json yarn.lock"
  teardown_large_env
}

test_large_amend() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock pnpm-lock.yaml 30
  lg_commitia FAKE_FAIL_MATCH='^Diff:' FAKE_FAIL_MATCH2='pnpm-lock' --amend
  expect_eq "Amend: não cria novo commit" "$(lg_count)" "1"
  expect_eq "Amend: arquivos entram no mesmo commit" "$(lg_files 0)" "README.md app.sh pnpm-lock.yaml"
  expect_contains "Amend: avisa que não separa" "$LG_OUT" "--amend"
  expect_contains "Amend: sem commit na sessão, vai ao último recurso" "$LG_OUT" "mensagem padrão de último recurso"
  teardown_large_env
}

test_large_disabled_and_config() {
  large_tests_available || return 0

  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock pnpm-lock.yaml 30
  lg_commitia COMMITIA_LARGE_FILES=false
  expect_eq "COMMITIA_LARGE_FILES=false: commit único" "$(lg_count)" "2"
  teardown_large_env

  # Padrões vindos do .commitiarc do projeto (substituem a lista padrão)
  setup_large_env
  echo 'COMMITIA_LARGE_FILE_PATTERNS="*.dat"' > "$LG_REPO/.commitiarc"
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock pnpm-lock.yaml 30
  lg_make_lock peso.dat 5
  lg_git add app.sh pnpm-lock.yaml peso.dat
  lg_commitia
  expect_eq "Padrões do .commitiarc: *.dat separado" "$(lg_files 0)" "peso.dat"
  expect_eq "Padrões do .commitiarc: lockfile deixa de ser especial" "$(lg_files 1)" "app.sh pnpm-lock.yaml"
  teardown_large_env

  # Valor inválido gera aviso e usa o padrão
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_commitia COMMITIA_LARGE_FILE_LINES=abc
  expect_contains "Limite inválido: aviso" "$LG_OUT" "COMMITIA_LARGE_FILE_LINES inválido"
  expect_eq "Limite inválido: commit realizado" "$(lg_count)" "2"
  teardown_large_env
}

test_large_files_argument() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  echo 'outro' > "$LG_REPO/outro.txt"
  lg_make_lock pnpm-lock.yaml 30
  lg_commitia app.sh pnpm-lock.yaml
  expect_eq "Arquivos na linha de comando: 2 commits" "$(lg_count)" "3"
  expect_eq "Arquivos na linha de comando: pequeno primeiro" "$(lg_files 1)" "app.sh"
  expect_eq "Arquivos na linha de comando: lockfile depois" "$(lg_files 0)" "pnpm-lock.yaml"
  expect_eq "Arquivos na linha de comando: outros arquivos intactos" "$(lg_git status --porcelain)" "?? outro.txt"
  teardown_large_env
}

test_large_interactive() {
  large_tests_available || return 0

  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock pnpm-lock.yaml 30
  LG_OUT=$( (cd "$LG_REPO" && printf 'SS' | HOME="$LG_DIR/home" PATH="$LG_DIR/bin:$PATH" FAKE_OUT="$LG_DIR/out" \
    "$COMMITIA" --provider claude -i 2>&1) | perl -pe 's/\e\[[0-9;]*m//g') || true
  expect_eq "Interativo (S,S): 2 commits" "$(lg_count)" "3"
  teardown_large_env

  # Cancelar no primeiro grupo: nada é commitado e o stage original é restaurado
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock pnpm-lock.yaml 30
  LG_OUT=$( (cd "$LG_REPO" && printf 'n' | HOME="$LG_DIR/home" PATH="$LG_DIR/bin:$PATH" FAKE_OUT="$LG_DIR/out" \
    "$COMMITIA" --provider claude -i 2>&1) | perl -pe 's/\e\[[0-9;]*m//g') || true
  expect_eq "Interativo (n): nenhum commit" "$(lg_count)" "1"
  expect_eq "Interativo (n): stage original restaurado" "$(lg_staged)" "app.sh pnpm-lock.yaml"
  teardown_large_env
}

test_large_special_names_and_deletion() {
  large_tests_available || return 0

  setup_large_env
  echo 'echo a' > "$LG_REPO/meu app.sh"
  lg_make_lock "meu pacote.lock" 12
  lg_commitia
  expect_eq "Nomes com espaço: pequeno" "$(lg_files 1)" "meu app.sh"
  expect_eq "Nomes com espaço: grande" "$(lg_files 0)" "meu pacote.lock"
  teardown_large_env

  # Remoção staged de um lockfile também é tratada separadamente
  setup_large_env
  lg_make_lock pnpm-lock.yaml 12
  lg_git add pnpm-lock.yaml
  lg_git commit -q -m "chore: adiciona lockfile"
  echo "mudou" >> "$LG_REPO/README.md"
  lg_git add README.md
  lg_git rm -q pnpm-lock.yaml
  lg_commitia
  expect_eq "Remoção de lockfile: pequeno primeiro" "$(lg_files 1)" "README.md"
  expect_eq "Remoção de lockfile: commit próprio" "$(lg_files 0)" "pnpm-lock.yaml"
  expect_eq "Remoção de lockfile: arquivo removido do HEAD" "$(lg_git ls-tree --name-only HEAD | tr '\n' ' ')" "README.md "
  teardown_large_env
}

test_large_unborn_repo() {
  large_tests_available || return 0
  LG_DIR=$(mktemp -d)
  mkdir -p "$LG_DIR/bin" "$LG_DIR/home" "$LG_DIR/out" "$LG_DIR/repo"
  LG_REPO="$LG_DIR/repo"
  fake_help_text claude > "$LG_DIR/bin/claude.help"
  cat > "$LG_DIR/bin/claude" << 'EOF2'
#!/usr/bin/env bash
case "$*" in
  *--version*) echo "1.2.3 (fake)"; exit 0 ;;
  *--help*) cat "$0.help"; exit 0 ;;
esac
cat > /dev/null
echo "feat(app): adiciona recurso"
EOF2
  chmod +x "$LG_DIR/bin/claude"
  git -C "$LG_REPO" init -q
  git -C "$LG_REPO" config user.email "test@test.com"
  git -C "$LG_REPO" config user.name "Test"
  git -C "$LG_REPO" config commit.gpgsign false
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock pnpm-lock.yaml 12
  lg_commitia
  expect_eq "Repo sem commits: 2 commits criados" "$(lg_count)" "2"
  expect_eq "Repo sem commits: lockfile no último" "$(lg_files 0)" "pnpm-lock.yaml"
  expect_eq "Repo sem commits: pequeno no primeiro" "$(lg_files 1)" "app.sh"
  teardown_large_env
}

# ----------------------------------------------------------------------------
# Validação de versão das CLIs (CLI antiga, erro em tempo de execução, CLI atualizada)
# ----------------------------------------------------------------------------

# Dados de cada provedor: binário, flag exigida (removida do --help para simular
# versão antiga) e trecho do comando de atualização
cli_case() {
  case "$1" in
    cursor) CASE_BIN="cursor-agent"; CASE_FLAG="--mode"; CASE_UPDATE="cursor-agent update" ;;
    copilot) CASE_BIN="copilot"; CASE_FLAG="--deny-tool"; CASE_UPDATE="npm install -g @github/copilot@latest" ;;
    claude) CASE_BIN="claude"; CASE_FLAG="--tools"; CASE_UPDATE="npm install -g @anthropic-ai/claude-code@latest" ;;
    codex) CASE_BIN="codex"; CASE_FLAG="--output-last-message"; CASE_UPDATE="npm install -g @openai/codex@latest" ;;
    gemini-cli) CASE_BIN="gemini"; CASE_FLAG="--skip-trust"; CASE_UPDATE="npm install -g @google/gemini-cli@latest" ;;
  esac
}

strip_ansi() { perl -pe 's/\e\[[0-9;]*m//g'; }

# (a) CLI antiga (sem a flag no --help): aborta antes de gerar, com mensagem de atualização
test_cli_outdated_preventive() {
  setup_fake_env
  cd "$FAKE_DIR/repo"
  local provider out rc
  for provider in cursor copilot claude codex gemini-cli; do
    cli_case "$provider"
    fake_help_text "$CASE_BIN" "$CASE_FLAG" > "$FAKE_DIR/cli/$CASE_BIN.help"
    rc=0
    out=$(PATH="$FAKE_DIR/git:$FAKE_DIR/cli:$PATH" $COMMITIA -d --provider "$provider" 2>&1 | strip_ansi; exit "${PIPESTATUS[0]}") || rc=$?
    expect_eq "CLI antiga ($provider): aborta com erro" "$([ "$rc" -ne 0 ] && echo sim)" "sim"
    expect_contains "CLI antiga ($provider): pede atualização" "$out" "precisa ser atualizada"
    expect_contains "CLI antiga ($provider): informa a flag ausente" "$out" "$CASE_FLAG"
    expect_contains "CLI antiga ($provider): informa a versão instalada" "$out" "1.2.3"
    expect_contains "CLI antiga ($provider): informa o comando de atualização" "$out" "$CASE_UPDATE"
    expect_not_contains "CLI antiga ($provider): aborta antes de gerar" "$out" "Gerando mensagem"
    expect_not_contains "CLI antiga ($provider): sem erro cru" "$out" "unknown option"

    # Variável para pular a checagem: segue normalmente
    out=$(PATH="$FAKE_DIR/git:$FAKE_DIR/cli:$PATH" COMMITIA_SKIP_CLI_VERSION_CHECK=true \
      $COMMITIA -d --provider "$provider" 2>&1 | strip_ansi || true)
    expect_contains "CLI antiga ($provider): COMMITIA_SKIP_CLI_VERSION_CHECK pula a checagem" "$out" "feat(app): adiciona novo recurso"
  done
  cd - > /dev/null
  rm -rf "$FAKE_DIR"
}

# (b) CLI que falha em tempo de execução com "unknown option": mensagem de atualização
test_cli_outdated_runtime() {
  setup_fake_env
  cd "$FAKE_DIR/repo"
  local provider out rc
  for provider in cursor copilot claude codex gemini-cli; do
    cli_case "$provider"
    rm -rf "$FAKE_REPO/.commitia"
    rc=0
    out=$(PATH="$FAKE_DIR/git:$FAKE_DIR/cli:$PATH" FAKE_RUNTIME_ERROR=1 \
      $COMMITIA -d --provider "$provider" 2>&1 | strip_ansi; exit "${PIPESTATUS[0]}") || rc=$?
    expect_eq "Erro em runtime ($provider): sai com erro" "$rc" "1"
    expect_contains "Erro em runtime ($provider): pede atualização" "$out" "precisa ser atualizada"
    expect_contains "Erro em runtime ($provider): comando de atualização" "$out" "$CASE_UPDATE"
    expect_not_contains "Erro em runtime ($provider): sem mensagem genérica" "$out" "Não foi possível gerar"
    expect_not_contains "Erro em runtime ($provider): sem erro cru" "$out" "error: unknown option"
    expect_eq "Erro em runtime ($provider): log mantém a saída bruta" \
      "$(grep -rl "unknown option" "$FAKE_REPO/.commitia/logs" 2>/dev/null | wc -l | tr -d ' ')" "1"
  done
  cd - > /dev/null
  rm -rf "$FAKE_DIR"
}

# (c) CLI atualizada: segue normalmente, sem aviso de atualização
test_cli_up_to_date() {
  setup_fake_env
  cd "$FAKE_DIR/repo"
  local provider out
  for provider in cursor copilot claude codex gemini-cli; do
    out=$(PATH="$FAKE_DIR/git:$FAKE_DIR/cli:$PATH" $COMMITIA -d --provider "$provider" 2>&1 | strip_ansi || true)
    expect_not_contains "CLI atualizada ($provider): sem aviso de atualização" "$out" "precisa ser atualizada"
    expect_contains "CLI atualizada ($provider): gera a mensagem" "$out" "feat(app): adiciona novo recurso"
  done
  cd - > /dev/null
  rm -rf "$FAKE_DIR"
}

# Fluxo de arquivos grandes: erro de flag na 1ª tentativa aborta sem fallback nem commits
test_cli_outdated_large_files_first_attempt() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock pnpm-lock.yaml 30
  lg_commitia FAKE_RUNTIME_ERROR='.'
  expect_eq "Arquivos grandes + CLI antiga: sai com erro" "$LG_RC" "1"
  expect_contains "Arquivos grandes + CLI antiga: pede atualização" "$LG_OUT" "precisa ser atualizada"
  expect_not_contains "Arquivos grandes + CLI antiga: sem último recurso" "$LG_OUT" "último recurso"
  expect_eq "Arquivos grandes + CLI antiga: nenhum commit criado" "$(lg_count)" "1"
  expect_eq "Arquivos grandes + CLI antiga: uma única chamada (sem loop)" "$(lg_nprompts)" "1"
  teardown_large_env
}

# Fluxo de arquivos grandes: erro de flag no fallback (resumo) avisa em vez de usar o último recurso
test_cli_outdated_large_files_summary_fallback() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock pnpm-lock.yaml 30
  lg_commitia FAKE_FAIL_MATCH='^Diff:' FAKE_FAIL_MATCH2='pnpm-lock' FAKE_RUNTIME_ERROR='^Resumo:'
  expect_eq "Fallback + CLI antiga: sai com erro" "$LG_RC" "1"
  expect_contains "Fallback + CLI antiga: pede atualização" "$LG_OUT" "precisa ser atualizada"
  expect_not_contains "Fallback + CLI antiga: não cai no último recurso" "$LG_OUT" "mensagem padrão de último recurso"
  expect_eq "Fallback + CLI antiga: só o commit dos pequenos" "$(lg_count)" "2"
  teardown_large_env
}

# ----------------------------------------------------------------------------
# Validação de versão do commitia (hermético: origem remota local via file://,
# instalação em diretório temporário, curl falso para offline; terminal
# interativo simulado com COMMITIA_TEST_FORCE_TTY e a resposta em stdin)
# ----------------------------------------------------------------------------

# Cópia do commitia com outra VERSION; imprime "EXEC-VERSAO-<versão>" quando
# COMMITIA_TEST_MARK está definido (prova qual versão rodou)
make_commitia_copy() {
  perl -pe "s/^VERSION=.*/VERSION=\"$2\"/; \$_ .= \"[ -z \\\"\\\${COMMITIA_TEST_MARK:-}\\\" ] || echo \\\"EXEC-VERSAO-\\\${VERSION}\\\"\\n\" if /^VERSION=/" "$COMMITIA" > "$1"
  chmod +x "$1"
}

# $1: versão local (padrão 1.0.0); $2: versão remota (padrão 9.9.9)
setup_update_env() {
  setup_large_env
  UP_LOCAL="${1:-1.0.0}"
  UP_REMOTE="${2:-9.9.9}"
  mkdir -p "$LG_DIR/remote/bin" "$LG_DIR/inst"
  make_commitia_copy "$LG_DIR/remote/bin/commitia" "$UP_REMOTE"
  make_commitia_copy "$LG_DIR/inst/commitia" "$UP_LOCAL"
  LG_COMMITIA="$LG_DIR/inst/commitia"
  echo 'echo a' > "$LG_REPO/app.sh"
}

teardown_update_env() {
  unset LG_COMMITIA LG_STDIN
  teardown_large_env
}

# commitia instalado (cópia) com checagem de versão ligada e terminal simulado
up_commitia() {
  lg_commitia COMMITIA_SKIP_UPDATE_CHECK=false COMMITIA_REPO_RAW_URL="file://$LG_DIR/remote" \
    COMMITIA_TEST_FORCE_TTY=true COMMITIA_TEST_MARK=1 "$@"
}

up_installed_version() { grep -m1 '^VERSION=' "$LG_DIR/inst/commitia" | cut -d'"' -f2; }

# curl falso: registra os argumentos e falha como em timeout (exit 28)
make_fake_curl() {
  cat > "$LG_DIR/bin/curl" << 'EOF4'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_CURL_LOG"
exit 28
EOF4
  chmod +x "$LG_DIR/bin/curl"
  FAKE_CURL_LOG="$LG_DIR/curl.log"
  export FAKE_CURL_LOG
}

# (A1) Remota maior + "s": atualiza, reexecuta e o commit é feito pela versão nova
test_update_accept() {
  large_tests_available || return 0
  setup_update_env
  LG_STDIN='s\n' up_commitia
  expect_eq "Atualização (s): sai com sucesso" "$LG_RC" "0"
  expect_contains "Atualização (s): informa a nova versão" "$LG_OUT" "Nova versão 9.9.9 disponível (você está na 1.0.0)"
  expect_contains "Atualização (s): pergunta se deseja atualizar" "$LG_OUT" "Deseja atualizar agora? [S/n]"
  expect_contains "Atualização (s): confirma a atualização" "$LG_OUT" "Atualizado para a versão 9.9.9"
  expect_eq "Atualização (s): binário instalado atualizado" "$(up_installed_version)" "9.9.9"
  expect_contains "Atualização (s): versão antiga iniciou o fluxo" "$LG_OUT" "EXEC-VERSAO-1.0.0"
  expect_contains "Atualização (s): reexecuta a versão nova" "$LG_OUT" "EXEC-VERSAO-9.9.9"
  expect_eq "Atualização (s): pergunta uma única vez (sem loop)" "$(printf '%s\n' "$LG_OUT" | grep -c 'Nova versão')" "1"
  expect_eq "Atualização (s): commit aplicado depois de atualizar" "$(lg_count)" "2"
  expect_eq "Atualização (s): IA chamada uma única vez" "$(lg_nprompts)" "1"
  expect_eq "Atualização (s): sem arquivos temporários na instalação" "$(ls "$LG_DIR/inst")" "commitia"
  teardown_update_env

  # Enter (resposta vazia) equivale a "sim" ([S/n])
  setup_update_env
  LG_STDIN='\n' up_commitia
  expect_eq "Atualização (Enter): atualiza" "$(up_installed_version)" "9.9.9"
  expect_eq "Atualização (Enter): commit aplicado" "$(lg_count)" "2"
  teardown_update_env
}

# (A2) Remota maior + "n": segue normalmente com a versão atual
test_update_decline() {
  large_tests_available || return 0
  setup_update_env
  LG_STDIN='n\n' up_commitia
  expect_eq "Atualização (n): sai com sucesso" "$LG_RC" "0"
  expect_contains "Atualização (n): avisa a nova versão" "$LG_OUT" "Nova versão 9.9.9 disponível"
  expect_contains "Atualização (n): segue com a versão atual" "$LG_OUT" "Seguindo com a versão atual (1.0.0)"
  expect_eq "Atualização (n): binário intacto" "$(up_installed_version)" "1.0.0"
  expect_not_contains "Atualização (n): não reexecuta" "$LG_OUT" "EXEC-VERSAO-9.9.9"
  expect_eq "Atualização (n): commit aplicado" "$(lg_count)" "2"
  teardown_update_env
}

# (A3) Offline/timeout: silencioso, sem erro, sem atraso repetido, com timeout curto
test_update_offline() {
  large_tests_available || return 0
  setup_update_env
  make_fake_curl
  LG_STDIN='s\n' up_commitia
  expect_eq "Offline: commit aplicado normalmente" "$(lg_count)" "2"
  expect_eq "Offline: sai com sucesso" "$LG_RC" "0"
  expect_not_contains "Offline: sem aviso de versão" "$LG_OUT" "Nova versão"
  expect_not_contains "Offline: sem pergunta" "$LG_OUT" "Deseja atualizar"
  expect_not_contains "Offline: sem erro" "$LG_OUT" "Erro"
  expect_not_contains "Offline: sem aviso" "$LG_OUT" "Aviso"
  expect_not_contains "Offline: sem erro do curl" "$LG_OUT" "curl"
  expect_contains "Offline: curl com timeout curto (3s)" "$(cat "$FAKE_CURL_LOG")" "--max-time 3"
  expect_eq "Offline: binário intacto" "$(up_installed_version)" "1.0.0"

  # Segunda execução: a falha ficou em cache (sem pagar a latência da rede de novo)
  echo 'echo b' > "$LG_REPO/app.sh"
  LG_STDIN='s\n' up_commitia
  expect_eq "Offline: não tenta a rede de novo logo em seguida" "$(wc -l < "$FAKE_CURL_LOG" | tr -d ' ')" "1"
  expect_eq "Offline: segundo commit aplicado" "$(lg_count)" "3"
  teardown_update_env
}

# (A4) Cache: respeita o intervalo, avisa enquanto pendente e revalida depois do prazo
test_update_cache() {
  large_tests_available || return 0
  setup_update_env
  local cache="$LG_DIR/home/.commitia/update-check"

  up_commitia -d
  expect_contains "Cache: 1ª consulta avisa a nova versão" "$LG_OUT" "Nova versão 9.9.9 disponível"
  expect_contains "Cache: grava a versão remota" "$(cat "$cache" 2>/dev/null)" "remote_version=9.9.9"

  # A origem muda, mas o cache ainda vale: continua avisando a versão pendente sem rede
  make_commitia_copy "$LG_DIR/remote/bin/commitia" "1.0.0"
  up_commitia -d
  expect_contains "Cache: avisa enquanto houver versão pendente (sem nova consulta)" "$LG_OUT" "Nova versão 9.9.9 disponível"

  # Intervalo 0: sempre consulta a rede (a origem já não tem versão nova)
  up_commitia COMMITIA_UPDATE_CHECK_INTERVAL_HOURS=0 -d
  expect_not_contains "Cache: intervalo 0 revalida na rede" "$LG_OUT" "Nova versão"

  # Cache vencido: consulta de novo e pega a versão nova da origem
  make_commitia_copy "$LG_DIR/remote/bin/commitia" "9.9.8"
  printf 'remote_version=9.9.9\nnext_check=1\n' > "$cache"
  up_commitia -d
  expect_contains "Cache: vencido consulta a rede" "$LG_OUT" "Nova versão 9.9.8 disponível"
  expect_contains "Cache: atualiza o arquivo" "$(cat "$cache")" "remote_version=9.9.8"

  # Intervalo configurável: cache de 2h atrás vale com 24h, mas vence com 1h
  make_commitia_copy "$LG_DIR/remote/bin/commitia" "9.9.7"
  printf 'remote_version=9.9.8\nnext_check=%s\n' "$(( $(date +%s) + 3600 ))" > "$cache"
  up_commitia -d
  expect_contains "Cache: dentro do prazo mantém a versão em cache" "$LG_OUT" "Nova versão 9.9.8 disponível"
  printf 'remote_version=9.9.8\nnext_check=%s\n' "$(( $(date +%s) - 10 ))" > "$cache"
  up_commitia COMMITIA_UPDATE_CHECK_INTERVAL_HOURS=1 -d
  expect_contains "Cache: após o prazo revalida" "$LG_OUT" "Nova versão 9.9.7 disponível"
  teardown_update_env
}

# (A5) Não interativo: só informa e segue (sem perguntar nem atualizar)
test_update_non_interactive() {
  large_tests_available || return 0
  setup_update_env
  LG_STDIN='s\n' up_commitia COMMITIA_TEST_FORCE_TTY=
  expect_eq "Não interativo: sai com sucesso" "$LG_RC" "0"
  expect_contains "Não interativo: informa a nova versão" "$LG_OUT" "Nova versão 9.9.9 disponível"
  expect_not_contains "Não interativo: não pergunta" "$LG_OUT" "Deseja atualizar"
  expect_contains "Não interativo: indica como atualizar" "$LG_OUT" "commitia --update"
  expect_eq "Não interativo: binário intacto" "$(up_installed_version)" "1.0.0"
  expect_eq "Não interativo: commit aplicado" "$(lg_count)" "2"
  teardown_update_env
}

# (A6) Proteção contra loop de reexecução e opção para desligar
test_update_loop_guard_and_skip() {
  large_tests_available || return 0
  setup_update_env
  LG_STDIN='s\n' up_commitia COMMITIA_UPDATED_REEXEC=1 -d
  expect_not_contains "Reexecução: não checa de novo (sem loop)" "$LG_OUT" "Nova versão"
  expect_not_contains "Reexecução: não pergunta" "$LG_OUT" "Deseja atualizar"
  expect_eq "Reexecução: binário intacto" "$(up_installed_version)" "1.0.0"

  # Origem que só entrega versão antiga mesmo após atualizar: no máximo uma reexecução
  make_commitia_copy "$LG_DIR/remote/bin/commitia" "1.0.1"
  make_commitia_copy "$LG_DIR/inst/commitia" "1.0.0"
  # a "nova" versão continua achando que há uma maior no cache (1.0.1 vs 1.0.1 não é maior)
  LG_STDIN='s\ns\ns\n' up_commitia
  expect_eq "Reexecução: uma única pergunta mesmo com várias respostas" "$(printf '%s\n' "$LG_OUT" | grep -c 'Deseja atualizar')" "1"
  teardown_update_env

  setup_update_env
  up_commitia COMMITIA_SKIP_UPDATE_CHECK=true -d
  expect_not_contains "COMMITIA_SKIP_UPDATE_CHECK=true desliga a checagem" "$LG_OUT" "Nova versão"
  expect_eq "COMMITIA_SKIP_UPDATE_CHECK=true: não cria cache" "$(ls "$LG_DIR/home/.commitia" 2>/dev/null | grep -c update-check || true)" "0"
  teardown_update_env
}

# (A7) --dry-run: informa a nova versão sem perguntar nem alterar o binário
test_update_dry_run() {
  large_tests_available || return 0
  setup_update_env
  LG_STDIN='s\n' up_commitia --dry-run
  expect_eq "Dry-run: sai com sucesso" "$LG_RC" "0"
  expect_contains "Dry-run: informa a nova versão" "$LG_OUT" "Nova versão 9.9.9 disponível"
  expect_contains "Dry-run: explica que não atualiza" "$LG_OUT" "--dry-run"
  expect_not_contains "Dry-run: não pergunta" "$LG_OUT" "Deseja atualizar"
  expect_eq "Dry-run: binário intacto" "$(up_installed_version)" "1.0.0"
  expect_eq "Dry-run: nenhum commit" "$(lg_count)" "1"
  expect_contains "Dry-run: continua gerando a mensagem" "$LG_OUT" "feat(app): adiciona recurso"
  teardown_update_env
}

# (A8) Falha ao atualizar: avisa e segue com a versão atual (sem perder o commit)
test_update_failure_continues() {
  large_tests_available || return 0
  setup_update_env
  # Cache diz que há versão nova, mas a origem não entrega o arquivo (download falha)
  mkdir -p "$LG_DIR/home/.commitia"
  printf 'remote_version=9.9.9\nnext_check=%s\n' "$(( $(date +%s) + 3600 ))" > "$LG_DIR/home/.commitia/update-check"
  rm -rf "$LG_DIR/remote"
  LG_STDIN='s\n' up_commitia
  expect_eq "Falha ao atualizar: sai com sucesso" "$LG_RC" "0"
  expect_contains "Falha ao atualizar: avisa claramente" "$LG_OUT" "A atualização falhou; seguindo com a versão atual (1.0.0)"
  expect_eq "Falha ao atualizar: binário intacto" "$(up_installed_version)" "1.0.0"
  expect_eq "Falha ao atualizar: commit aplicado" "$(lg_count)" "2"
  teardown_update_env

  # Arquivo remoto inválido (não é um commitia): não instala
  setup_update_env
  printf '#!/usr/bin/env bash\nVERSION="9.9.9"\nif then fi fi\n' > "$LG_DIR/remote/bin/commitia"
  LG_STDIN='s\n' up_commitia
  expect_contains "Remoto inválido: avisa" "$LG_OUT" "A atualização falhou"
  expect_eq "Remoto inválido: binário intacto" "$(up_installed_version)" "1.0.0"
  expect_eq "Remoto inválido: commit aplicado" "$(lg_count)" "2"
  teardown_update_env
}

# (A9) Comparação semântica (numérica), não só "diferente"
test_update_semver() {
  large_tests_available || return 0
  setup_update_env 1.0.9 1.0.10
  up_commitia -d
  expect_contains "Semver: 1.0.10 > 1.0.9 avisa" "$LG_OUT" "Nova versão 1.0.10 disponível (você está na 1.0.9)"
  teardown_update_env

  setup_update_env 1.0.10 1.0.9
  up_commitia -d
  expect_not_contains "Semver: remota menor não avisa" "$LG_OUT" "Nova versão"
  teardown_update_env

  setup_update_env 1.0.15 1.0.15
  LG_STDIN='s\n' up_commitia
  expect_not_contains "Semver: mesma versão não avisa" "$LG_OUT" "Nova versão"
  expect_eq "Semver: mesma versão faz o commit normal" "$(lg_count)" "2"
  teardown_update_env

  setup_update_env 1.9.0 1.10.0
  up_commitia -d
  expect_contains "Semver: 1.10.0 > 1.9.0 avisa" "$LG_OUT" "Nova versão 1.10.0 disponível"
  teardown_update_env
}

# (A10) --help, --version e --update não disparam a checagem; --update continua funcionando
test_update_not_on_help_version_update() {
  large_tests_available || return 0
  setup_update_env
  make_fake_curl
  local out
  out=$(cd "$LG_REPO" && env HOME="$LG_DIR/home" PATH="$LG_DIR/bin:$PATH" COMMITIA_SKIP_UPDATE_CHECK=false \
    COMMITIA_TEST_FORCE_TTY=true COMMITIA_REPO_RAW_URL="file://$LG_DIR/remote" \
    "$LG_DIR/inst/commitia" --version 2>&1 </dev/null)
  expect_contains "--version funciona" "$out" "CommitIA v1.0.0"
  out=$(cd "$LG_REPO" && env HOME="$LG_DIR/home" PATH="$LG_DIR/bin:$PATH" COMMITIA_SKIP_UPDATE_CHECK=false \
    COMMITIA_TEST_FORCE_TTY=true COMMITIA_REPO_RAW_URL="file://$LG_DIR/remote" \
    "$LG_DIR/inst/commitia" --help 2>&1 </dev/null)
  expect_contains "--help documenta COMMITIA_SKIP_UPDATE_CHECK" "$out" "COMMITIA_SKIP_UPDATE_CHECK"
  expect_contains "--help documenta COMMITIA_UPDATE_CHECK_INTERVAL_HOURS" "$out" "COMMITIA_UPDATE_CHECK_INTERVAL_HOURS"
  expect_not_contains "--version/--help não avisam nova versão" "$out" "Nova versão 9.9.9"
  expect_eq "--version/--help não consultam a rede" "$(cat "$FAKE_CURL_LOG" 2>/dev/null | wc -l | tr -d ' ')" "0"
  teardown_update_env

  # --update: usa o commitia do PATH, pergunta uma vez (próprio prompt) e reinstala
  setup_update_env
  out=$(cd "$LG_REPO" && printf 's' | env HOME="$LG_DIR/home" PATH="$LG_DIR/inst:$PATH" \
    COMMITIA_REPO_RAW_URL="file://$LG_DIR/remote" COMMITIA_SKIP_UPDATE_CHECK=false \
    "$LG_DIR/inst/commitia" --update 2>&1 | strip_ansi)
  expect_contains "--update: informa as versões" "$out" "Versão remota: 9.9.9"
  expect_contains "--update: atualiza com sucesso" "$out" "Atualizado com sucesso para a versão 9.9.9"
  expect_eq "--update: binário atualizado" "$(up_installed_version)" "9.9.9"
  expect_not_contains "--update: não dispara a checagem automática" "$out" "Nova versão"
  # Já na última versão: informa; --force reinstala
  out=$(cd "$LG_REPO" && printf 's' | env HOME="$LG_DIR/home" PATH="$LG_DIR/inst:$PATH" \
    COMMITIA_REPO_RAW_URL="file://$LG_DIR/remote" "$LG_DIR/inst/commitia" --update 2>&1 | strip_ansi)
  expect_contains "--update: já na versão mais recente" "$out" "Você já está na versão mais recente"
  out=$(cd "$LG_REPO" && printf 's' | env HOME="$LG_DIR/home" PATH="$LG_DIR/inst:$PATH" \
    COMMITIA_REPO_RAW_URL="file://$LG_DIR/remote" "$LG_DIR/inst/commitia" --update --force 2>&1 | strip_ansi)
  expect_contains "--update --force: reinstala" "$out" "Reinstalar a mesma versão 9.9.9"
  expect_contains "--update --force: conclui" "$out" "Atualizado com sucesso"
  teardown_update_env
}

# (A11) Rodando de um clone do repositório (.git ao lado de bin/): não se sobrescreve
test_update_dev_checkout_not_overwritten() {
  large_tests_available || return 0
  setup_update_env
  mkdir -p "$LG_DIR/clone/bin" "$LG_DIR/clone/.git"
  make_commitia_copy "$LG_DIR/clone/bin/commitia" "1.0.0"
  LG_COMMITIA="$LG_DIR/clone/bin/commitia"
  LG_STDIN='s\n' up_commitia
  expect_contains "Clone de desenvolvimento: informa a nova versão" "$LG_OUT" "Nova versão 9.9.9 disponível"
  expect_contains "Clone de desenvolvimento: não se sobrescreve" "$LG_OUT" "clone do repositório"
  expect_not_contains "Clone de desenvolvimento: não pergunta" "$LG_OUT" "Deseja atualizar"
  expect_eq "Clone de desenvolvimento: arquivo intacto" "$(grep -m1 '^VERSION=' "$LG_DIR/clone/bin/commitia" | cut -d'"' -f2)" "1.0.0"
  expect_eq "Clone de desenvolvimento: commit aplicado" "$(lg_count)" "2"
  teardown_update_env
}

# (B) CLI desatualizada em terminal interativo: oferece atualizar e continua (ou aborta)
fake_cli_run() {
  # $1: provedor; demais: variáveis VAR=valor de ambiente; stdin = $FAKE_STDIN
  local provider="$1"; shift
  CASE_OUT=$(cd "$FAKE_DIR/repo" && printf '%b' "${FAKE_STDIN-}" | env PATH="$FAKE_DIR/git:$FAKE_DIR/cli:$PATH" \
    FAKE_NPM_LOG="$FAKE_NPM_LOG" "$@" "$COMMITIA" --provider "$provider" ${FAKE_ARGS-} 2>&1 | strip_ansi; exit "${PIPESTATUS[1]}") && CASE_RC=0 || CASE_RC=$?
}

test_cli_update_accept() {
  setup_fake_env
  cd "$FAKE_DIR/repo"
  local provider
  for provider in cursor copilot claude codex gemini-cli; do
    cli_case "$provider"
    fake_help_text "$CASE_BIN" "$CASE_FLAG" > "$FAKE_DIR/cli/$CASE_BIN.help"
    rm -f "$FAKE_NPM_LOG" "$FAKE_DIR/cli/$CASE_BIN.updated"
    FAKE_STDIN='s\n' fake_cli_run "$provider" COMMITIA_TEST_FORCE_TTY=true
    expect_eq "CLI antiga + s ($provider): sai com sucesso" "$CASE_RC" "0"
    expect_contains "CLI antiga + s ($provider): pergunta se deseja atualizar" "$CASE_OUT" "Deseja atualizar agora?"
    expect_contains "CLI antiga + s ($provider): executa a atualização" "$CASE_OUT" "Executando: $(echo "$CASE_UPDATE" | sed 's/ *(ou.*//')"
    if [ "$provider" = "cursor" ]; then
      expect_eq "CLI antiga + s ($provider): rodou 'update'" "$(cat "$FAKE_DIR/cli/$CASE_BIN.updated" 2>/dev/null)" "update"
    else
      expect_eq "CLI antiga + s ($provider): rodou o npm" "$(cat "$FAKE_NPM_LOG" 2>/dev/null)" "$(echo "$CASE_UPDATE" | sed 's/ *(ou.*//; s/^npm //')"
    fi
    expect_contains "CLI antiga + s ($provider): revalida e continua" "$CASE_OUT" "atualizada; revalidando"
    expect_contains "CLI antiga + s ($provider): gera a mensagem" "$CASE_OUT" "feat(app): adiciona novo recurso"
    expect_not_contains "CLI antiga + s ($provider): não aborta" "$CASE_OUT" "precisa ser atualizada"
  done
  cd - > /dev/null
  rm -rf "$FAKE_DIR"
}

test_cli_update_decline_and_failures() {
  setup_fake_env
  cd "$FAKE_DIR/repo"
  local provider
  for provider in cursor claude; do
    cli_case "$provider"
    fake_help_text "$CASE_BIN" "$CASE_FLAG" > "$FAKE_DIR/cli/$CASE_BIN.help"
    rm -f "$FAKE_NPM_LOG" "$FAKE_DIR/cli/$CASE_BIN.updated"

    # "n": aborta com a mensagem de atualização e não roda nada
    FAKE_STDIN='n\n' fake_cli_run "$provider" COMMITIA_TEST_FORCE_TTY=true
    expect_eq "CLI antiga + n ($provider): aborta" "$([ "$CASE_RC" -ne 0 ] && echo sim)" "sim"
    expect_contains "CLI antiga + n ($provider): mensagem de atualização" "$CASE_OUT" "precisa ser atualizada"
    expect_contains "CLI antiga + n ($provider): comando de atualização" "$CASE_OUT" "$CASE_UPDATE"
    expect_not_contains "CLI antiga + n ($provider): não gera mensagem" "$CASE_OUT" "Gerando mensagem"
    expect_eq "CLI antiga + n ($provider): nada foi executado" "$(cat "$FAKE_NPM_LOG" "$FAKE_DIR/cli/$CASE_BIN.updated" 2>/dev/null | wc -l | tr -d ' ')" "0"

    # Atualização falha: aborta com a mensagem
    FAKE_STDIN='s\n' fake_cli_run "$provider" COMMITIA_TEST_FORCE_TTY=true FAKE_UPDATE_FAIL=1
    expect_eq "CLI antiga + update falha ($provider): aborta" "$([ "$CASE_RC" -ne 0 ] && echo sim)" "sim"
    expect_contains "CLI antiga + update falha ($provider): avisa a falha" "$CASE_OUT" "A atualização da CLI '$CASE_BIN' falhou"
    expect_contains "CLI antiga + update falha ($provider): mensagem de atualização" "$CASE_OUT" "precisa ser atualizada"

    # Atualiza, mas a CLI continua sem a flag: aborta
    FAKE_STDIN='s\n' fake_cli_run "$provider" COMMITIA_TEST_FORCE_TTY=true FAKE_UPDATE_NOFIX=1
    expect_eq "CLI antiga + update sem efeito ($provider): aborta" "$([ "$CASE_RC" -ne 0 ] && echo sim)" "sim"
    expect_contains "CLI antiga + update sem efeito ($provider): avisa" "$CASE_OUT" "ainda não suporta"
    expect_contains "CLI antiga + update sem efeito ($provider): mensagem de atualização" "$CASE_OUT" "precisa ser atualizada"

    # --dry-run não instala nada: aborta como antes, sem perguntar
    rm -f "$FAKE_NPM_LOG" "$FAKE_DIR/cli/$CASE_BIN.updated"
    FAKE_ARGS='-d' FAKE_STDIN='s\n' fake_cli_run "$provider" COMMITIA_TEST_FORCE_TTY=true
    expect_eq "CLI antiga + dry-run ($provider): aborta" "$([ "$CASE_RC" -ne 0 ] && echo sim)" "sim"
    expect_not_contains "CLI antiga + dry-run ($provider): não pergunta" "$CASE_OUT" "Deseja atualizar"
    expect_eq "CLI antiga + dry-run ($provider): nada foi executado" "$(cat "$FAKE_NPM_LOG" "$FAKE_DIR/cli/$CASE_BIN.updated" 2>/dev/null | wc -l | tr -d ' ')" "0"

    # Não interativo: comportamento anterior (aviso e abort, sem perguntar)
    FAKE_STDIN='s\n' fake_cli_run "$provider"
    expect_eq "CLI antiga não interativo ($provider): aborta" "$([ "$CASE_RC" -ne 0 ] && echo sim)" "sim"
    expect_not_contains "CLI antiga não interativo ($provider): não pergunta" "$CASE_OUT" "Deseja atualizar"
    expect_contains "CLI antiga não interativo ($provider): mensagem de atualização" "$CASE_OUT" "precisa ser atualizada"
    expect_eq "CLI antiga não interativo ($provider): nada foi executado" "$(cat "$FAKE_NPM_LOG" "$FAKE_DIR/cli/$CASE_BIN.updated" 2>/dev/null | wc -l | tr -d ' ')" "0"
  done
  cd - > /dev/null
  rm -rf "$FAKE_DIR"
}

# ----------------------------------------------------------------------------
# Skill para agentes de IA (commitia skill) - hermético: HOME e repo temporários
# ----------------------------------------------------------------------------

test_skill() {
  local d out rc orig="$PWD"
  d=$(mktemp -d)
  mkdir -p "$d/home" "$d/proj/sub"
  cd "$d/proj"
  git init > /dev/null 2>&1 || true

  # Destinos de projeto (executados a partir de uma subpasta: usa a raiz do repo)
  cd "$d/proj/sub"
  HOME="$d/home" $COMMITIA skill cursor > /dev/null 2>&1
  [ -f "$d/proj/.cursor/skills/commitia/SKILL.md" ] && pass "Skill cursor grava em .cursor/skills" || fail "Skill cursor não gravou o arquivo"
  HOME="$d/home" $COMMITIA skill vscode copilot > /dev/null 2>&1
  [ -f "$d/proj/.github/skills/commitia/SKILL.md" ] && pass "Skill vscode/copilot grava em .github/skills" || fail "Skill vscode/copilot não gravou o arquivo"
  HOME="$d/home" $COMMITIA skill claude > /dev/null 2>&1
  [ -f "$d/proj/.claude/skills/commitia/SKILL.md" ] && pass "Skill claude grava em .claude/skills" || fail "Skill claude não gravou o arquivo"

  # Conteúdo: frontmatter válido e recursos do commitia
  local f="$d/proj/.cursor/skills/commitia/SKILL.md" content
  content=$(cat "$f")
  expect_eq "Skill começa com frontmatter" "$(head -1 "$f")" "---"
  expect_contains "Skill tem name" "$content" "name: commitia"
  expect_contains "Skill tem description" "$content" "description:"
  expect_contains "Skill documenta --no-stage" "$content" "--no-stage"
  expect_contains "Skill documenta --dry-run" "$content" "--dry-run"
  expect_contains "Skill documenta arquivos grandes" "$content" "Arquivos grandes"
  expect_contains "Skill registra a versão" "$content" "commitia v$("$COMMITIA" --version | grep -oE '[0-9][0-9.]*')"

  # Todas as opções do --help principal aparecem na skill
  local opt missing=""
  for opt in --message --type --scope --interactive --dry-run --amend --no-stage --provider --lang --update; do
    printf '%s' "$content" | grep -qF -- "$opt" || missing="$missing $opt"
  done
  expect_eq "Skill cobre todas as opções do commitia" "$missing" ""

  # Global usa HOME do usuário
  HOME="$d/home" $COMMITIA skill cursor copilot claude --global > /dev/null 2>&1
  [ -f "$d/home/.cursor/skills/commitia/SKILL.md" ] && pass "Skill global cursor em ~/.cursor/skills" || fail "Skill global cursor ausente"
  [ -f "$d/home/.copilot/skills/commitia/SKILL.md" ] && pass "Skill global copilot em ~/.copilot/skills" || fail "Skill global copilot ausente"
  [ -f "$d/home/.claude/skills/commitia/SKILL.md" ] && pass "Skill global claude em ~/.claude/skills" || fail "Skill global claude ausente"

  # Idempotência, proteção contra sobrescrita e --force
  out=$(HOME="$d/home" $COMMITIA skill cursor 2>&1)
  expect_contains "Skill idêntica: já atualizada" "$out" "já está atualizada"
  echo "# editada" >> "$f"
  rc=0; out=$(HOME="$d/home" $COMMITIA skill cursor 2>&1) || rc=$?
  expect_eq "Skill diferente sem --force: falha" "$rc" "1"
  expect_contains "Skill diferente sem --force: avisa" "$out" "--force"
  expect_contains "Skill editada preservada sem --force" "$(cat "$f")" "# editada"
  HOME="$d/home" $COMMITIA skill cursor --force > /dev/null 2>&1
  expect_not_contains "--force sobrescreve a skill" "$(cat "$f")" "# editada"

  # Destino 'file': stdout, caminho padrão e caminho customizado
  out=$(HOME="$d/home" $COMMITIA skill file -o - 2>&1)
  expect_eq "file -o - imprime a skill" "$(printf '%s\n' "$out" | head -1)" "---"
  cd "$d"
  HOME="$d/home" $COMMITIA skill file > /dev/null 2>&1
  [ -f "$d/commitia-skill.md" ] && pass "file grava ./commitia-skill.md por padrão" || fail "file não gravou o arquivo padrão"
  HOME="$d/home" $COMMITIA skill file -o "$d/out/dir/SKILL.md" > /dev/null 2>&1
  [ -f "$d/out/dir/SKILL.md" ] && pass "file -o cria diretórios e grava no caminho" || fail "file -o não gravou"

  # Dry-run não cria arquivos
  HOME="$d/home" $COMMITIA skill file -o "$d/dry/SKILL.md" --dry-run > /dev/null 2>&1
  [ ! -e "$d/dry" ] && pass "skill --dry-run não cria arquivos" || fail "skill --dry-run criou arquivos"

  # Erros: destino inválido, opção inválida e sem destino fora de terminal
  out=$(HOME="$d/home" $COMMITIA skill vim 2>&1 || true)
  expect_contains "Destino inválido é rejeitado" "$out" "Destino desconhecido"
  out=$(HOME="$d/home" $COMMITIA skill cursor --xyz 2>&1 || true)
  expect_contains "Opção inválida em skill é rejeitada" "$out" "Opção desconhecida para 'skill'"
  rc=0; out=$(HOME="$d/home" $COMMITIA skill < /dev/null 2>&1) || rc=$?
  expect_eq "Sem destino e sem terminal: falha" "$rc" "1"
  expect_contains "Sem destino e sem terminal: orienta o uso" "$out" "informe o destino"

  # Menu interativo (terminal simulado): 3 = Copilot, 2 = global
  HOME="$d/home2" COMMITIA_TEST_FORCE_TTY=true bash -c "printf '3\n2\n' | $COMMITIA skill" > /dev/null 2>&1
  [ -f "$d/home2/.copilot/skills/commitia/SKILL.md" ] && pass "Menu interativo instala a skill escolhida" || fail "Menu interativo não instalou a skill"

  # Help
  expect_contains "skill --help lista os destinos" "$($COMMITIA skill --help)" "copilot"
  expect_contains "Help principal menciona a skill" "$($COMMITIA --help)" "skill"

  cd "$orig"
  rm -rf "$d"
}

# ----------------------------------------------------------------------------
# .commitiaignore (hermético: git real em repositórios temporários + CLI falsa)
#
#   +arquivo  -> commitado normalmente, mas o diff NÃO vai para a IA
#   arquivo   -> NÃO é adicionado automaticamente; entra só se já estiver staged
# ----------------------------------------------------------------------------

# Cria o harness de parsing/matching: extrai do bin/commitia as funções do módulo
# (o script chama main ao final, então não pode ser carregado com 'source').
setup_ignore_harness() {
  IG_HARNESS=$(mktemp)
  {
    echo 'warn() { echo "WARN: $*" >&2; }'
    echo 'info() { :; }'
    echo 'IGNORE_FILE_NAME=".commitiaignore"'
    local fn
    for fn in ignore_glob_to_regex parse_ignore_file ignore_match_any is_manual_only_path is_ai_excluded_path; do
      awk -v n="$fn" '$0 ~ "^" n "\\(\\) \\{" {p=1} p {print} p && /^\}/ {p=0}' "$COMMITIA"
    done
  } > "$IG_HARNESS"
}

# Conteúdo do .commitiaignore ($1), tipo de regra ($2: manual|noai), caminho ($3) -> yes|no
ig_match() {
  local f result
  f=$(mktemp)
  printf '%b' "$1" > "$f"
  result=$(bash -c '
    source "$1"
    parse_ignore_file "$2"
    case "$3" in
      manual) is_manual_only_path "$4" ;;
      noai) is_ai_excluded_path "$4" ;;
    esac && echo yes || echo no' _ "$IG_HARNESS" "$f" "$2" "$3" 2>/dev/null)
  rm -f "$f"
  echo "$result"
}

# Quantidade de regras lidas: "<manual> <noai>"
ig_counts() {
  local f result
  f=$(mktemp)
  printf '%b' "$1" > "$f"
  result=$(bash -c '
    source "$1"
    parse_ignore_file "$2"
    echo "${#IGNORE_MANUAL_RES[@]} ${#IGNORE_NOAI_RES[@]}"' _ "$IG_HARNESS" "$f" 2>/dev/null)
  rm -f "$f"
  echo "$result"
}

test_ignore_parsing() {
  setup_ignore_harness

  expect_eq "Parsing: comentários e linhas vazias são ignorados" \
    "$(ig_counts '# comentário\n\n   \n  # outro\nfoo.txt\n')" "1 0"
  expect_eq "Parsing: '+' conta como regra de IA, sem prefixo como regra manual" \
    "$(ig_counts 'a.txt\n+b.txt\n# c\n+d/**\ne/\n')" "2 2"
  expect_eq "Parsing: espaços e CRLF são tolerados" \
    "$(ig_counts '  a.txt  \r\n+ b.txt\r\n\r\n')" "1 1"
  expect_eq "Parsing: arquivo vazio não tem regras" "$(ig_counts '')" "0 0"
  expect_eq "Parsing: última linha sem quebra de linha é lida" "$(ig_counts 'a.txt\n+b.txt')" "1 1"
  expect_eq "Parsing: negação (!) é ignorada" "$(ig_counts '!a.txt\nb.txt\n')" "1 0"
  expect_eq "Parsing: '+' sozinho é ignorado" "$(ig_counts '+\n+   \nb.txt\n')" "1 0"
  expect_eq "Parsing: '+' com espaço depois: padrão correto" \
    "$(ig_match '+ package-lock.json\n' noai package-lock.json)" "yes"
  expect_eq "Parsing: entrada '+' não vira regra manual" \
    "$(ig_match '+package-lock.json\n' manual package-lock.json)" "no"
  expect_eq "Parsing: entrada sem prefixo não vira regra de IA" \
    "$(ig_match 'package-lock.json\n' noai package-lock.json)" "no"
  expect_eq "Parsing: comentário não casa como padrão" "$(ig_match '# a.txt\n' manual '# a.txt')" "no"
  expect_eq "Parsing: '#' escapado vira padrão literal" "$(ig_match '\\#hash.txt\n' manual '#hash.txt')" "yes"
  expect_eq "Parsing: '+' escapado vira padrão sem prefixo" "$(ig_match '\\+mais.txt\n' manual '+mais.txt')" "yes"

  # Globs (mesmo resultado para as duas semânticas; usa 'manual')
  expect_eq "Glob: nome sem barra casa na raiz" "$(ig_match 'nome.txt\n' manual nome.txt)" "yes"
  expect_eq "Glob: nome sem barra casa em qualquer pasta" "$(ig_match 'nome.txt\n' manual a/b/nome.txt)" "yes"
  expect_eq "Glob: nome diferente não casa" "$(ig_match 'nome.txt\n' manual outro.txt)" "no"
  expect_eq "Glob: nome não casa por sufixo" "$(ig_match 'nome.txt\n' manual xnome.txt)" "no"
  expect_eq "Glob: *.lock casa na raiz" "$(ig_match '*.lock\n' manual yarn.lock)" "yes"
  expect_eq "Glob: *.lock casa em subpasta" "$(ig_match '*.lock\n' manual app/Cargo.lock)" "yes"
  expect_eq "Glob: *.lock não casa .locked" "$(ig_match '*.lock\n' manual a.locked)" "no"
  expect_eq "Glob: dir/** casa arquivos e subpastas" "$(ig_match 'dir/**\n' manual dir/a/b.txt)" "yes"
  expect_eq "Glob: dir/** casa filho direto" "$(ig_match 'dir/**\n' manual dir/a.txt)" "yes"
  expect_eq "Glob: dir/** é ancorado na raiz" "$(ig_match 'dir/**\n' manual outro/dir/a.txt)" "no"
  expect_eq "Glob: dir/** não casa pasta homônima parcial" "$(ig_match 'dir/**\n' manual dir2/a.txt)" "no"
  expect_eq "Glob: pasta com barra final casa o conteúdo" "$(ig_match 'build/\n' manual build/out.o)" "yes"
  expect_eq "Glob: pasta com barra final casa em qualquer nível" "$(ig_match 'build/\n' manual src/build/out.o)" "yes"
  expect_eq "Glob: pasta com barra final não casa arquivo homônimo" "$(ig_match 'build/\n' manual build)" "no"
  expect_eq "Glob: nome sem barra casa o conteúdo de uma pasta homônima" "$(ig_match 'tmp\n' manual tmp/a.txt)" "yes"
  expect_eq "Glob: barra no meio ancora na raiz" "$(ig_match 'docs/*.md\n' manual docs/a.md)" "yes"
  expect_eq "Glob: barra no meio não casa em outra pasta" "$(ig_match 'docs/*.md\n' manual x/docs/a.md)" "no"
  expect_eq "Glob: * não atravessa pastas" "$(ig_match 'docs/*.md\n' manual docs/sub/a.md)" "no"
  expect_eq "Glob: barra inicial ancora na raiz" "$(ig_match '/raiz.txt\n' manual raiz.txt)" "yes"
  expect_eq "Glob: barra inicial não casa em subpasta" "$(ig_match '/raiz.txt\n' manual sub/raiz.txt)" "no"
  expect_eq "Glob: **/ casa na raiz" "$(ig_match '**/gen/*.js\n' manual gen/a.js)" "yes"
  expect_eq "Glob: **/ casa em profundidade" "$(ig_match '**/gen/*.js\n' manual a/b/gen/a.js)" "yes"
  expect_eq "Glob: **/ respeita o restante do padrão" "$(ig_match '**/gen/*.js\n' manual a/gen/b/c.js)" "no"
  expect_eq "Glob: a/**/b casa zero pastas" "$(ig_match 'a/**/b\n' manual a/b)" "yes"
  expect_eq "Glob: a/**/b casa várias pastas" "$(ig_match 'a/**/b\n' manual a/x/y/b)" "yes"
  expect_eq "Glob: ? casa um caractere" "$(ig_match 'f?.txt\n' manual f1.txt)" "yes"
  expect_eq "Glob: ? não casa zero caracteres" "$(ig_match 'f?.txt\n' manual f.txt)" "no"
  expect_eq "Glob: ? não casa a barra" "$(ig_match 'f?g\n' manual f/g)" "no"
  expect_eq "Glob: classe [ab]" "$(ig_match '[ab].txt\n' manual b.txt)" "yes"
  expect_eq "Glob: classe [ab] não casa c" "$(ig_match '[ab].txt\n' manual c.txt)" "no"
  expect_eq "Glob: classe negada [!a]" "$(ig_match '[!a].txt\n' manual b.txt)" "yes"
  expect_eq "Glob: classe negada [!a] não casa a" "$(ig_match '[!a].txt\n' manual a.txt)" "no"
  expect_eq "Glob: ponto é literal" "$(ig_match 'a.b\n' manual axb)" "no"
  expect_eq "Glob: caracteres especiais de regex são literais" "$(ig_match 'a+b(1).txt\n' manual 'a+b(1).txt')" "yes"
  expect_eq "Glob: espaço no nome" "$(ig_match 'meu arquivo.txt\n' manual 'meu arquivo.txt')" "yes"
  expect_eq "Glob: a mesma sintaxe vale para '+'" "$(ig_match '+dist/**\n' noai dist/app.js)" "yes"
  expect_eq "Glob: '+' com *.lock em subpasta" "$(ig_match '+*.lock\n' noai web/yarn.lock)" "yes"

  rm -f "$IG_HARNESS"
}

# Cria o .commitiaignore e o commita (baseline: 2 commits no repositório)
ig_setup() {
  printf '%b' "$1" > "$LG_REPO/.commitiaignore"
  lg_git add .commitiaignore
  lg_git commit -q -m "chore: add commitiaignore"
}

ig_subject() { lg_git log -1 --format=%s; }

test_ignore_absent_file() {
  large_tests_available || return 0
  setup_large_env
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_commitia
  expect_eq "Sem .commitiaignore: commit normal" "$(lg_count)" "2"
  expect_eq "Sem .commitiaignore: sem erro" "$LG_RC" "0"
  expect_not_contains "Sem .commitiaignore: não menciona o arquivo" "$LG_OUT" ".commitiaignore"
  teardown_large_env
}

test_ignore_plus_committed_but_not_sent_to_ai() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '# lockfile vai no commit, fora da IA\n+package-lock.json\n'
  echo 'echo a' > "$LG_REPO/app.sh"
  echo 'CONTEUDO-SECRETO-DO-LOCK' > "$LG_REPO/package-lock.json"
  lg_commitia
  expect_eq "'+': um único commit" "$(lg_count)" "3"
  expect_eq "'+': arquivo '+' entra no commit junto com os demais" "$(lg_files 0)" "app.sh package-lock.json"
  expect_eq "'+': working tree limpa" "$(lg_git status --porcelain)" ""
  expect_eq "'+': IA chamada uma vez" "$(lg_nprompts)" "1"
  expect_contains "'+': IA recebe o diff dos demais arquivos" "$(lg_prompt 1)" "echo a"
  expect_not_contains "'+': conteúdo do arquivo '+' NÃO vai à IA" "$(lg_prompt 1)" "CONTEUDO-SECRETO-DO-LOCK"
  expect_not_contains "'+': diff do arquivo '+' NÃO vai à IA" "$(lg_prompt 1)" "diff --git a/package-lock.json"
  expect_contains "'+': IA é avisada do arquivo omitido (só o nome)" "$(lg_prompt 1)" "package-lock.json"
  expect_contains "'+': mensagem informa que o arquivo não vai à IA" "$LG_OUT" "conteúdo não enviado à IA"
  teardown_large_env
}

test_ignore_plus_glob_and_dir() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '+*.lock\n+generated/**\n'
  mkdir -p "$LG_REPO/generated/deep" "$LG_REPO/web"
  echo 'echo a' > "$LG_REPO/app.sh"
  echo 'SEGREDO-LOCK' > "$LG_REPO/web/yarn.lock"
  echo 'SEGREDO-GERADO' > "$LG_REPO/generated/deep/out.js"
  lg_commitia
  expect_eq "'+' com globs: um commit com tudo" "$(lg_files 0)" "app.sh generated/deep/out.js web/yarn.lock"
  expect_not_contains "'+' com glob *.lock: fora da IA" "$(lg_prompt 1)" "SEGREDO-LOCK"
  expect_not_contains "'+' com dir/**: fora da IA" "$(lg_prompt 1)" "SEGREDO-GERADO"
  expect_contains "'+' com globs: demais arquivos vão à IA" "$(lg_prompt 1)" "echo a"
  teardown_large_env
}

test_ignore_plus_only_files() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '+package-lock.json\n'
  echo 'SEGREDO-LOCK' > "$LG_REPO/package-lock.json"
  lg_commitia
  expect_eq "Só arquivos '+': commit criado" "$(lg_count)" "3"
  expect_eq "Só arquivos '+': commit com o arquivo" "$(lg_files 0)" "package-lock.json"
  expect_eq "Só arquivos '+': IA não é chamada" "$(lg_nprompts)" "0"
  expect_eq "Só arquivos '+': mensagem padrão sem IA" "$(ig_subject)" "chore(deps): atualiza package-lock.json"
  expect_contains "Só arquivos '+': avisa que nada vai à IA" "$LG_OUT" "nada é enviado à IA"
  teardown_large_env
}

test_ignore_plus_large_file_not_split() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '+yarn.lock\n'
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_make_lock yarn.lock 30
  lg_make_lock package-lock.json 30
  lg_commitia
  expect_eq "'+' grande: 2 commits novos (só o outro lockfile é separado)" "$(lg_count)" "4"
  expect_eq "'+' grande: arquivo '+' fica no commit dos pequenos" "$(lg_files 1)" "app.sh yarn.lock"
  expect_eq "'+' grande: lockfile sem '+' continua em commit próprio" "$(lg_files 0)" "package-lock.json"
  expect_not_contains "'+' grande: conteúdo do '+' fora da IA (commit dos pequenos)" "$(lg_prompt 1)" "pacote1: 1.0.1"
  expect_contains "'+' grande: lockfile sem '+' é enviado normalmente" "$(lg_prompt 2)" "pacote1: 1.0.1"
  teardown_large_env
}

test_ignore_plus_large_fallback_summary_omits_content() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '+yarn.lock\n'
  echo 'echo a' > "$LG_REPO/app.sh"
  local i
  for i in $(seq 1 30); do echo "YARN-SEGREDO-$i"; done > "$LG_REPO/yarn.lock"
  lg_make_lock package-lock.json 30
  # IA falha para o diff completo do lockfile; o fallback resumido não pode vazar o '+'
  lg_commitia FAKE_FAIL_MATCH='Diff:' FAKE_FAIL_MATCH2='package-lock'
  expect_eq "Fallback com '+': commits criados" "$(lg_count)" "4"
  local all_prompts
  all_prompts=$(cat "$LG_DIR"/out/prompt-*.txt)
  expect_contains "Fallback com '+': o outro lockfile segue o fluxo normal" "$all_prompts" "package-lock.json"
  expect_not_contains "Fallback com '+': nenhum prompt contém o conteúdo do '+'" "$all_prompts" "YARN-SEGREDO"
  teardown_large_env
}

test_ignore_plain_not_auto_added() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '# não commitar sozinho\n.env.local\n'
  echo 'echo a' > "$LG_REPO/app.sh"
  echo 'SEGREDO-ENV' > "$LG_REPO/.env.local"
  lg_commitia
  expect_eq "Sem prefixo: um commit" "$(lg_count)" "3"
  expect_eq "Sem prefixo: arquivo não vai no commit" "$(lg_files 0)" "app.sh"
  expect_eq "Sem prefixo: continua não rastreado" "$(lg_git status --porcelain)" "?? .env.local"
  expect_eq "Sem prefixo: nunca vai à IA (nem foi staged)" "$(lg_prompt 1 | grep -c SEGREDO-ENV || true)" "0"
  expect_contains "Sem prefixo: informa o arquivo não adicionado" "$LG_OUT" "Não adicionados automaticamente"
  expect_contains "Sem prefixo: lista o arquivo" "$LG_OUT" ".env.local"
  teardown_large_env
}

test_ignore_plain_tracked_modified_not_added() {
  large_tests_available || return 0
  setup_large_env
  echo 'v1' > "$LG_REPO/config.local"
  lg_git add config.local
  lg_git commit -q -m "chore: add config"
  ig_setup 'config.local\n'
  echo 'v2' > "$LG_REPO/config.local"
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_commitia
  expect_eq "Sem prefixo (rastreado): só o outro arquivo no commit" "$(lg_files 0)" "app.sh"
  expect_eq "Sem prefixo (rastreado): modificação continua fora do stage" "$(lg_git status --porcelain)" " M config.local"
  teardown_large_env
}

test_ignore_plain_deleted_not_added() {
  large_tests_available || return 0
  setup_large_env
  echo 'x' > "$LG_REPO/velho.local"
  lg_git add velho.local
  lg_git commit -q -m "chore: add velho"
  ig_setup 'velho.local\n'
  rm "$LG_REPO/velho.local"
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_commitia
  expect_eq "Sem prefixo (removido): remoção não é commitada sozinha" "$(lg_files 0)" "app.sh"
  expect_eq "Sem prefixo (removido): remoção continua pendente" "$(lg_git status --porcelain)" " D velho.local"
  teardown_large_env
}

test_ignore_plain_only_changes_errors() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '.env.local\n'
  echo 'SEGREDO-ENV' > "$LG_REPO/.env.local"
  lg_commitia
  expect_eq "Só arquivos sem prefixo: nenhum commit" "$(lg_count)" "2"
  expect_eq "Só arquivos sem prefixo: erro" "$LG_RC" "1"
  expect_contains "Só arquivos sem prefixo: explica o motivo" "$LG_OUT" "estão no .commitiaignore"
  expect_eq "Só arquivos sem prefixo: nada foi staged" "$(lg_staged)" ""
  expect_eq "Só arquivos sem prefixo: IA não chamada" "$(lg_nprompts)" "0"
  teardown_large_env
}

test_ignore_plain_manually_staged_is_committed() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '.env.local\n'
  echo 'echo a' > "$LG_REPO/app.sh"
  echo 'SEGREDO-ENV' > "$LG_REPO/.env.local"
  lg_git add .env.local
  lg_commitia
  expect_eq "Staged manual sem prefixo: entra no commit" "$(lg_files 0)" ".env.local"
  expect_eq "Staged manual sem prefixo: não removido do stage antes do commit (commit criado)" "$(lg_count)" "3"
  expect_contains "Staged manual sem prefixo: conteúdo vai à IA (escolha explícita)" "$(lg_prompt 1)" "SEGREDO-ENV"
  expect_eq "Staged manual sem prefixo: demais arquivos seguem o fluxo padrão (não adicionados)" "$(lg_git status --porcelain)" "?? app.sh"
  teardown_large_env
}

test_ignore_plain_manually_staged_with_file_arg() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '*.key\n'
  mkdir -p "$LG_REPO/src"
  echo 'echo a' > "$LG_REPO/src/a.sh"
  echo 'CHAVE-V1' > "$LG_REPO/src/dev.key"
  lg_git add src/dev.key
  echo 'CHAVE-V2' > "$LG_REPO/src/dev.key"   # alteração posterior, fora do stage
  lg_commitia src/
  expect_eq "Staged manual + diretório: stage manual e novos arquivos entram" "$(lg_files 0)" "src/a.sh src/dev.key"
  expect_eq "Staged manual + diretório: versão staged é preservada (não re-adicionada)" "$(lg_git show HEAD:src/dev.key)" "CHAVE-V1"
  expect_eq "Staged manual + diretório: alteração posterior continua pendente" "$(lg_git status --porcelain)" " M src/dev.key"
  teardown_large_env
}

test_ignore_plain_dir_arg_skips_ignored() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '*.key\nsrc/private/**\n'
  mkdir -p "$LG_REPO/src/private" "$LG_REPO/other"
  echo 'echo a' > "$LG_REPO/src/a.sh"
  echo 'K' > "$LG_REPO/src/dev.key"
  echo 'P' > "$LG_REPO/src/private/p.txt"
  echo 'o' > "$LG_REPO/other/o.sh"
  lg_commitia src/
  expect_eq "Diretório como argumento: só o que não está no .commitiaignore" "$(lg_files 0)" "src/a.sh"
  expect_contains "Diretório como argumento: informa o ignorado" "$LG_OUT" "src/dev.key"
  expect_contains "Diretório como argumento: informa o ignorado (dir/**)" "$LG_OUT" "src/private/p.txt"
  expect_contains "Diretório como argumento: fora do diretório continua intocado" "$(lg_git status --porcelain)" "other/"
  teardown_large_env
}

test_ignore_plain_explicit_file_arg_is_added() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '.env.local\n'
  echo 'SEGREDO-ENV' > "$LG_REPO/.env.local"
  lg_commitia .env.local
  expect_eq "Arquivo explícito como argumento: equivale a git add manual" "$(lg_files 0)" ".env.local"
  expect_contains "Arquivo explícito como argumento: conteúdo vai à IA" "$(lg_prompt 1)" "SEGREDO-ENV"
  teardown_large_env
}

test_ignore_plain_no_stage_option() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '.env.local\n'
  echo 'SEGREDO-ENV' > "$LG_REPO/.env.local"
  lg_git add .env.local
  lg_commitia --no-stage
  expect_eq "--no-stage: staged manual sem prefixo é commitado" "$(lg_files 0)" ".env.local"
  teardown_large_env
}

test_ignore_precedence_both_rules() {
  large_tests_available || return 0
  setup_large_env
  ig_setup 'secret.dat\n+secret.dat\n'
  echo 'echo a' > "$LG_REPO/app.sh"
  echo 'SEGREDO-DAT' > "$LG_REPO/secret.dat"
  lg_commitia
  expect_eq "Precedência (ambas): não é adicionado automaticamente" "$(lg_files 0)" "app.sh"
  expect_eq "Precedência (ambas): continua fora do commit" "$(lg_git status --porcelain)" "?? secret.dat"

  # Staged manualmente: entra no commit, mas o conteúdo continua fora da IA ('+' vence no eixo IA)
  echo 'echo b' >> "$LG_REPO/app.sh"
  lg_git add secret.dat app.sh
  lg_commitia
  expect_eq "Precedência (ambas), staged manual: vai no commit" "$(lg_files 0)" "app.sh secret.dat"
  expect_not_contains "Precedência (ambas), staged manual: conteúdo fora da IA" "$(cat "$LG_DIR"/out/prompt-*.txt)" "SEGREDO-DAT"
  teardown_large_env
}

test_ignore_precedence_ai_only_when_staged() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '.env.local\n+*.lock\n'
  echo 'SEGREDO-ENV' > "$LG_REPO/.env.local"
  echo 'SEGREDO-LOCK' > "$LG_REPO/a.lock"
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_commitia
  expect_eq "Regras distintas: '+' commitado, sem prefixo não" "$(lg_files 0)" "a.lock app.sh"
  expect_eq "Regras distintas: sem prefixo fica de fora" "$(lg_git status --porcelain)" "?? .env.local"
  expect_not_contains "Regras distintas: '+' fora da IA" "$(lg_prompt 1)" "SEGREDO-LOCK"
  teardown_large_env
}

test_ignore_dry_run_keeps_rules() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '+package-lock.json\n.env.local\n'
  echo 'echo a' > "$LG_REPO/app.sh"
  echo 'SEGREDO-LOCK' > "$LG_REPO/package-lock.json"
  echo 'SEGREDO-ENV' > "$LG_REPO/.env.local"
  lg_commitia -d
  expect_eq "Dry-run: nenhum commit" "$(lg_count)" "2"
  expect_eq "Dry-run: '+' staged, sem prefixo não" "$(lg_staged)" "app.sh package-lock.json"
  expect_not_contains "Dry-run: '+' fora da IA" "$(lg_prompt 1)" "SEGREDO-LOCK"
  expect_not_contains "Dry-run: sem prefixo fora da IA" "$(lg_prompt 1)" "SEGREDO-ENV"
  teardown_large_env
}

test_ignore_comments_and_blank_lines_integration() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '# comentário\n\n   \n+package-lock.json   \n\n# fim\n'
  echo 'echo a' > "$LG_REPO/app.sh"
  echo 'SEGREDO-LOCK' > "$LG_REPO/package-lock.json"
  lg_commitia
  expect_contains "Comentários/linhas vazias: 1 regra lida" "$LG_OUT" "1 regra(s)"
  expect_not_contains "Comentários/linhas vazias: '+' funciona" "$(lg_prompt 1)" "SEGREDO-LOCK"
  teardown_large_env
}

test_ignore_negation_warns() {
  large_tests_available || return 0
  setup_large_env
  ig_setup '!a.txt\n'
  echo 'echo a' > "$LG_REPO/app.sh"
  lg_commitia
  expect_contains "Negação: avisa que não é suportada" "$LG_OUT" "negação"
  expect_eq "Negação: não impede o commit" "$(lg_files 0)" "app.sh"
  teardown_large_env
}

test_ignore_help_documents_file() {
  if $COMMITIA --help | grep -q "COMMITIAIGNORE" && $COMMITIA --help | grep -q "DIFERENTE da do .gitignore"; then
    pass "Help documenta o .commitiaignore"
  else
    fail "Help não documenta o .commitiaignore"
  fi
}

# --config (configuração pela linha de comando)
# ----------------------------------------------------------------------------

setup_config_env() {
  CF_DIR=$(mktemp -d)
  CF_HOME="$CF_DIR/home"
  CF_REPO="$CF_DIR/repo"
  mkdir -p "$CF_HOME" "$CF_REPO" "$CF_DIR/bin" "$CF_DIR/plain"
  git -C "$CF_REPO" init -q
}

teardown_config_env() {
  rm -rf "$CF_DIR"
}

# Executa "commitia --config ..." com HOME isolado, dentro do repo temporário
# (ou em $CF_WORKDIR). Saída sem ANSI em $CF_OUT e código de saída em $CF_RC.
cfg() {
  local out
  out=$( (cd "${CF_WORKDIR:-$CF_REPO}" && env -u COMMITIA_PROVIDER -u COMMITIA_LANGUAGE -u COMMITIA_AUTO_STAGE \
    -u COMMITIA_LARGE_FILES -u COMMITIA_CLAUDE_MODEL -u COMMITIA_CLI_TIMEOUT \
    HOME="$CF_HOME" "$COMMITIA" --config "$@" 2>&1; echo "RC=$?") | perl -pe 's/\e\[[0-9;]*m//g')
  CF_RC=$(echo "$out" | sed -n 's/^RC=//p')
  CF_OUT=$(echo "$out" | sed '/^RC=[0-9]*$/d')
}

cf_global() { cat "$CF_HOME/.commitiarc" 2>/dev/null | tr -d '\r'; }
cf_count() { grep -c "^$1=" "$CF_HOME/.commitiarc" 2>/dev/null || true; }

test_config() {
  setup_config_env

  # Definir e ler (global é o padrão)
  cfg provider copilot
  expect_eq "Config: define provider (rc)" "$CF_RC" "0"
  expect_contains "Config: define provider (mensagem)" "$CF_OUT" "provider = copilot"
  expect_contains "Config: grava no arquivo global" "$(cf_global)" 'COMMITIA_PROVIDER="copilot"'
  cfg provider
  expect_eq "Config: lê provider" "$CF_OUT" "copilot"
  cfg PROVIDER
  expect_eq "Config: chave em maiúsculas" "$CF_OUT" "copilot"
  cfg COMMITIA_PROVIDER
  expect_eq "Config: chave com prefixo COMMITIA_" "$CF_OUT" "copilot"

  # Substitui sem duplicar e preserva o restante do arquivo
  printf '# meu comentario\nCOMMITIA_LANGUAGE="en"\nCOMMITIA_PROVIDER="copilot"\nOUTRA="x"\n' > "$CF_HOME/.commitiarc"
  cfg provider claude
  expect_eq "Config: substitui sem duplicar" "$(cf_count COMMITIA_PROVIDER)" "1"
  expect_contains "Config: novo valor gravado" "$(cf_global)" 'COMMITIA_PROVIDER="claude"'
  expect_contains "Config: preserva comentário" "$(cf_global)" "# meu comentario"
  expect_contains "Config: preserva outras variáveis" "$(cf_global)" 'OUTRA="x"'
  expect_contains "Config: preserva idioma" "$(cf_global)" 'COMMITIA_LANGUAGE="en"'

  # Apelidos e caixa
  cfg lang PT
  expect_eq "Config: lang/PT normaliza" "$(cf_global | grep '^COMMITIA_LANGUAGE=')" 'COMMITIA_LANGUAGE="pt"'
  cfg provider COPILOT
  cfg provider
  expect_eq "Config: provedor aceita qualquer caixa" "$CF_OUT" "copilot"

  # Validação: erro, código 1 e nada alterado
  cfg provider inexistente
  expect_eq "Config: provedor inválido (rc)" "$CF_RC" "1"
  expect_contains "Config: provedor inválido (mensagem)" "$CF_OUT" "provedor inválido"
  cfg provider
  expect_eq "Config: provedor inválido não altera" "$CF_OUT" "copilot"
  cfg language fr
  expect_eq "Config: idioma inválido" "$CF_RC" "1"
  cfg auto-stage talvez
  expect_eq "Config: booleano inválido" "$CF_RC" "1"
  cfg large-file-lines abc
  expect_eq "Config: número inválido" "$CF_RC" "1"
  cfg chave-inexistente x
  expect_eq "Config: chave desconhecida (rc)" "$CF_RC" "1"
  expect_contains "Config: chave desconhecida (mensagem)" "$CF_OUT" "Chave desconhecida"
  cfg provider a b
  expect_eq "Config: argumentos demais" "$CF_RC" "1"

  # Padrão e listagem
  cfg large-file-lines
  expect_eq "Config: valor padrão" "$CF_OUT" "1000"
  cfg
  expect_eq "Config: listagem (rc)" "$CF_RC" "0"
  expect_contains "Config: listagem mostra provider" "$CF_OUT" "provider"
  expect_contains "Config: listagem mostra origem global" "$CF_OUT" "global"
  expect_contains "Config: listagem mostra origem padrão" "$CF_OUT" "padrão"

  # Projeto (--local) tem prioridade sobre o global
  cfg --local provider claude
  expect_eq "Config: --local (rc)" "$CF_RC" "0"
  expect_contains "Config: --local grava no repo" "$(cat "$CF_REPO/.commitiarc")" 'COMMITIA_PROVIDER="claude"'
  cfg provider
  expect_eq "Config: projeto vence o global" "$CF_OUT" "claude"
  cfg --global provider
  expect_eq "Config: --global lê só o global" "$CF_OUT" "copilot"
  cfg --local --list
  expect_contains "Config: --local --list" "$CF_OUT" "claude"
  cfg --local --unset provider
  cfg provider
  expect_eq "Config: --unset local volta ao global" "$CF_OUT" "copilot"

  # --unset global
  cfg --unset provider
  expect_eq "Config: --unset global (rc)" "$CF_RC" "0"
  expect_eq "Config: --unset remove a linha" "$(cf_count COMMITIA_PROVIDER)" "0"
  cfg provider
  expect_eq "Config: --unset volta ao padrão" "$CF_OUT" "amp"
  expect_contains "Config: --unset preserva o resto" "$(cf_global)" 'OUTRA="x"'
  cfg --unset provider
  expect_contains "Config: --unset de chave ausente" "$CF_OUT" "nada a remover"

  # Valores com espaço e caracteres especiais
  cfg large-file-patterns "pnpm-lock.yaml yarn.lock"
  cfg large-file-patterns
  expect_eq "Config: valor com espaço" "$CF_OUT" "pnpm-lock.yaml yarn.lock"
  cfg large-file-patterns "it's \$x \"q\" \`b\` \\z"
  cfg large-file-patterns
  expect_eq "Config: aspas, \$, crase e barra" "$CF_OUT" "it's \$x \"q\" \`b\` \\z"

  # Arquivo salvo com CRLF (Bloco de Notas no Windows)
  printf 'COMMITIA_PROVIDER="ollama"\r\nCOMMITIA_LANGUAGE="en"\r\n' > "$CF_HOME/.commitiarc"
  cfg provider
  expect_eq "Config: lê arquivo com CRLF" "$CF_OUT" "ollama"
  cfg provider codex
  expect_eq "Config: reescreve arquivo com CRLF" "$(cf_count COMMITIA_PROVIDER)" "1"
  cfg provider
  expect_eq "Config: valor após reescrever CRLF" "$CF_OUT" "codex"

  # Variável de ambiente (menor prioridade que os arquivos)
  rm -f "$CF_HOME/.commitiarc"
  CF_OUT=$( (cd "$CF_REPO" && HOME="$CF_HOME" COMMITIA_CLAUDE_MODEL=sonnet "$COMMITIA" --config claude-model 2>&1))
  expect_eq "Config: lê variável de ambiente" "$CF_OUT" "sonnet"

  # --local fora de um repositório Git
  CF_WORKDIR="$CF_DIR/plain" cfg --local provider claude
  expect_eq "Config: --local fora do git" "$CF_RC" "1"
  CF_WORKDIR="$CF_DIR/plain" cfg provider copilot
  expect_eq "Config: global funciona fora do git" "$CF_RC" "0"

  # Flags de config sem --config
  if (cd "$CF_REPO" && HOME="$CF_HOME" "$COMMITIA" --local 2>&1 | grep -q "só podem ser usados com --config"); then
    pass "Config: --local sem --config é rejeitado"
  else
    fail "Config: --local sem --config não é rejeitado"
  fi

  teardown_config_env
}

# A execução normal usa o provedor gravado por --config (sem --provider)
test_config_is_used() {
  large_tests_available || return 0
  # CLIs falsas não listam as flags exigidas no --help: testa só a configuração
  local -x COMMITIA_SKIP_CLI_VERSION_CHECK=true
  setup_config_env
  cat > "$CF_DIR/bin/claude" << 'EOF2'
#!/usr/bin/env bash
cat > /dev/null
echo "feat(app): adiciona recurso"
EOF2
  chmod +x "$CF_DIR/bin/claude"

  cfg provider claude
  echo 'echo a' > "$CF_REPO/app.sh"
  local out
  out=$( (cd "$CF_REPO" && env -u COMMITIA_PROVIDER HOME="$CF_HOME" PATH="$CF_DIR/bin:$PATH" "$COMMITIA" -d 2>&1) | perl -pe 's/\e\[[0-9;]*m//g')
  expect_contains "Config usada: provedor gravado" "$out" "Gerando mensagem com IA (claude)"
  expect_contains "Config usada: mensagem gerada" "$out" "feat(app): adiciona recurso"

  # --provider na linha de comando continua tendo prioridade
  out=$( (cd "$CF_REPO" && env -u COMMITIA_PROVIDER HOME="$CF_HOME" PATH="$CF_DIR/bin:$PATH" "$COMMITIA" -d --provider ollama 2>&1) | perl -pe 's/\e\[[0-9;]*m//g' || true)
  expect_not_contains "Config usada: --provider vence o arquivo" "$out" "Gerando mensagem com IA (claude)"
  teardown_config_env
}

# ----------------------------------------------------------------------------
# Prompt como argumento (copilot/cursor): limite de tamanho (Windows: ~32 mil)
# ----------------------------------------------------------------------------

test_cli_argv_limit() {
  large_tests_available || return 0
  # CLI falsa não lista as flags exigidas no --help: testa só o limite de argv
  local -x COMMITIA_SKIP_CLI_VERSION_CHECK=true
  setup_config_env
  # Copilot falso: grava o tamanho do último argumento (o prompt) e responde
  cat > "$CF_DIR/bin/copilot" << 'EOF2'
#!/usr/bin/env bash
last=""
for a in "$@"; do last="$a"; done
printf '%s' "${#last}" > "$FAKE_LEN_FILE"
echo "feat(app): adiciona recurso"
EOF2
  chmod +x "$CF_DIR/bin/copilot"
  git -C "$CF_REPO" config user.email t@t.t
  git -C "$CF_REPO" config user.name teste
  # Diff bem maior que o limite
  for i in $(seq 1 3000); do echo "linha de teste número $i com algum texto"; done > "$CF_REPO/grande.txt"
  git -C "$CF_REPO" add -A

  local len out
  FAKE_LEN_FILE="$CF_DIR/len.txt"
  out=$( (cd "$CF_REPO" && HOME="$CF_HOME" PATH="$CF_DIR/bin:$PATH" FAKE_LEN_FILE="$FAKE_LEN_FILE" \
    COMMITIA_ARG_MAX_CHARS=5000 "$COMMITIA" -d --provider copilot 2>&1) | perl -pe 's/\e\[[0-9;]*m//g')
  len=$(cat "$FAKE_LEN_FILE" 2>/dev/null || echo 0)
  expect_contains "Argv: mensagem gerada com diff grande" "$out" "feat(app): adiciona recurso"
  if [ "$len" -le 5000 ] && [ "$len" -gt 0 ]; then
    pass "Argv: prompt respeita o limite ($len <= 5000)"
  else
    fail "Argv: prompt maior que o limite ($len > 5000)"
  fi

  # Sem limite (0): o diff inteiro (até COMMITIA_MAX_DIFF_CHARS) segue como argumento
  out=$( (cd "$CF_REPO" && HOME="$CF_HOME" PATH="$CF_DIR/bin:$PATH" FAKE_LEN_FILE="$FAKE_LEN_FILE" \
    COMMITIA_ARG_MAX_CHARS=0 "$COMMITIA" -d --provider copilot 2>&1) | perl -pe 's/\e\[[0-9;]*m//g')
  len=$(cat "$FAKE_LEN_FILE" 2>/dev/null || echo 0)
  if [ "$len" -gt 5000 ]; then
    pass "Argv: sem limite envia o diff completo ($len caracteres)"
  else
    fail "Argv: sem limite deveria enviar mais que 5000 ($len)"
  fi
  teardown_config_env
}

# ----------------------------------------------------------------------------
# Erros visíveis no terminal (não só no log)
# ----------------------------------------------------------------------------

test_errors_on_terminal() {
  large_tests_available || return 0
  # CLIs falsas não listam as flags exigidas no --help: testa só a exibição de erros
  local -x COMMITIA_SKIP_CLI_VERSION_CHECK=true
  setup_config_env
  git -C "$CF_REPO" config user.email t@t.t
  git -C "$CF_REPO" config user.name teste

  # Falha de commit: hook rejeita a mensagem com uma explicação
  cat > "$CF_DIR/bin/copilot" << 'EOF2'
#!/usr/bin/env bash
echo "feat(app): adiciona recurso"
EOF2
  chmod +x "$CF_DIR/bin/copilot"
  printf '#!/bin/sh\necho "REJEITADO-TESTE: mensagem fora do padrão" >&2\nexit 1\n' > "$CF_REPO/.git/hooks/commit-msg"
  chmod +x "$CF_REPO/.git/hooks/commit-msg"
  echo 'echo a' > "$CF_REPO/app.sh"
  local out
  out=$( (cd "$CF_REPO" && HOME="$CF_HOME" PATH="$CF_DIR/bin:$PATH" "$COMMITIA" --provider copilot 2>&1) | perl -pe 's/\e\[[0-9;]*m//g' || true)
  expect_contains "Erro no terminal: falha de commit aparece" "$out" "Falha ao realizar commit"
  expect_contains "Erro no terminal: saída do hook aparece" "$out" "REJEITADO-TESTE"
  rm -f "$CF_REPO/.git/hooks/commit-msg"

  # Falha da IA: a CLI diz que não está autenticada
  cat > "$CF_DIR/bin/copilot" << 'EOF2'
#!/usr/bin/env bash
echo "Error: No authentication information found."
exit 1
EOF2
  chmod +x "$CF_DIR/bin/copilot"
  git -C "$CF_REPO" reset -q
  out=$( (cd "$CF_REPO" && HOME="$CF_HOME" PATH="$CF_DIR/bin:$PATH" "$COMMITIA" -d --provider copilot 2>&1) | perl -pe 's/\e\[[0-9;]*m//g' || true)
  expect_contains "Erro no terminal: falha da IA aparece" "$out" "No authentication information found"
  expect_contains "Erro no terminal: dica de login" "$out" "copilot login"
  teardown_config_env
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
test_skill
test_unknown_provider
test_cli_provider_missing_binary
test_cli_provider_generates_message
test_cli_outdated_preventive
test_cli_outdated_runtime
test_cli_up_to_date
test_cli_outdated_large_files_first_attempt
test_cli_outdated_large_files_summary_fallback
test_cli_update_accept
test_cli_update_decline_and_failures
test_update_accept
test_update_decline
test_update_offline
test_update_cache
test_update_non_interactive
test_update_loop_guard_and_skip
test_update_dry_run
test_update_failure_continues
test_update_semver
test_update_not_on_help_version_update
test_update_dev_checkout_not_overwritten
test_large_none
test_large_split_lockfile
test_large_only_lockfiles
test_large_single_lockfile
test_large_by_lines
test_large_by_bytes_diff
test_large_binary
test_large_fallback_summary
test_large_no_session_commit_goes_to_last_resort
test_large_last_resort
test_large_dry_run
test_large_small_failure_restores
test_large_commit_hook_failure
test_large_amend
test_large_disabled_and_config
test_large_files_argument
test_large_interactive
test_large_special_names_and_deletion
test_large_unborn_repo
test_ignore_parsing
test_ignore_absent_file
test_ignore_plus_committed_but_not_sent_to_ai
test_ignore_plus_glob_and_dir
test_ignore_plus_only_files
test_ignore_plus_large_file_not_split
test_ignore_plus_large_fallback_summary_omits_content
test_ignore_plain_not_auto_added
test_ignore_plain_tracked_modified_not_added
test_ignore_plain_deleted_not_added
test_ignore_plain_only_changes_errors
test_ignore_plain_manually_staged_is_committed
test_ignore_plain_manually_staged_with_file_arg
test_ignore_plain_dir_arg_skips_ignored
test_ignore_plain_explicit_file_arg_is_added
test_ignore_plain_no_stage_option
test_ignore_precedence_both_rules
test_ignore_precedence_ai_only_when_staged
test_ignore_dry_run_keeps_rules
test_ignore_comments_and_blank_lines_integration
test_ignore_negation_warns
test_ignore_help_documents_file
test_config
test_config_is_used
test_cli_argv_limit
test_errors_on_terminal

echo ""
echo "====================================="
echo -e "  Resultados: ${GREEN}$TESTS_PASSED passou${NC}, ${RED}$TESTS_FAILED falhou${NC}"
echo "====================================="
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
  exit 1
fi


