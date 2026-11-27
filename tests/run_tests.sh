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

  cat > "$LG_DIR/bin/claude" << 'EOF2'
#!/usr/bin/env bash
prompt=$(cat)
n=$(ls "$FAKE_OUT" 2>/dev/null | wc -l | tr -d ' ')
printf '%s' "$prompt" > "$FAKE_OUT/prompt-$((n + 1)).txt"
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
  LG_OUT=$( (cd "$LG_REPO" && env -u FAKE_FAIL_MATCH -u FAKE_FAIL_MATCH2 -u COMMITIA_LARGE_FILES -u COMMITIA_LARGE_FILE_LINES \
    -u COMMITIA_LARGE_FILE_BYTES -u COMMITIA_LARGE_FILE_PATTERNS \
    HOME="$LG_DIR/home" PATH="$LG_DIR/bin:$PATH" FAKE_OUT="$LG_DIR/out" \
    ${envs[@]+"${envs[@]}"} "$COMMITIA" --provider claude "$@" 2>&1; echo "RC=$?") | perl -pe 's/\e\[[0-9;]*m//g')
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
  cat > "$LG_DIR/bin/claude" << 'EOF2'
#!/usr/bin/env bash
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
test_config
test_config_is_used

echo ""
echo "====================================="
echo -e "  Resultados: ${GREEN}$TESTS_PASSED passou${NC}, ${RED}$TESTS_FAILED falhou${NC}"
echo "====================================="
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
  exit 1
fi


