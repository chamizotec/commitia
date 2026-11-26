#!/usr/bin/env bash
#
# Script de instalação do CommitIA
#

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configurações
REPO_URL="https://github.com/chamizotec/commitia"
REPO_RAW_URL="https://raw.githubusercontent.com/chamizotec/commitia/main"
INSTALL_DIR="${COMMITIA_INSTALL_DIR:-$HOME/.local/bin}"
SCRIPT_NAME="commitia"

print_banner() {
  echo -e "${PURPLE}"
  echo '   ____                          _ _   ___    _    '
  echo '  / ___|___  _ __ ___  _ __ ___ (_) |_|_ _|  / \   '
  echo ' | |   / _ \| '\''_ ` _ \| '\''_ ` _ \| | __|| |  / _ \  '
  echo ' | |__| (_) | | | | | | | | | | | | |_ | | / ___ \ '
  echo '  \____\___/|_| |_| |_|_| |_| |_|_|\__|___/_/   \_\'
  echo -e "${NC}"
  echo -e "${CYAN}  Instalador - Commits inteligentes com IA${NC}"
  echo ""
}

error() {
  echo -e "${RED}✗ Erro: $1${NC}" >&2
  exit 1
}

success() {
  echo -e "${GREEN}✓ $1${NC}"
}

info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

# Detecta se está rodando via pipe (curl | bash)
is_piped() {
  # Se BASH_SOURCE está vazio ou não existe, provavelmente está via pipe
  [ -z "${BASH_SOURCE[0]}" ] || [ "${BASH_SOURCE[0]}" = "bash" ] || [ ! -f "${BASH_SOURCE[0]}" ]
}

# Detecta o diretório do script (para instalação local)
get_script_dir() {
  local source="${BASH_SOURCE[0]}"
  while [ -h "$source" ]; do
    local dir
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$dir/$source"
  done
  cd -P "$(dirname "$source")" && pwd
}

# Verifica dependências
check_dependencies() {
  info "Verificando dependências..."
  
  # Git é obrigatório
  if ! command -v git &>/dev/null; then
    error "Git não encontrado. Instale o Git primeiro."
  fi
  success "Git encontrado"
  
  # curl é necessário para instalação remota
  if ! command -v curl &>/dev/null; then
    error "curl não encontrado. Instale o curl primeiro."
  fi
  success "curl encontrado"
  
  # Verifica provedores de IA (pelo menos um)
  local has_provider=false
  
  if command -v amp &>/dev/null; then
    success "amp CLI encontrado"
    has_provider=true
  fi
  
  if command -v cursor-agent &>/dev/null; then
    success "Cursor CLI (cursor-agent) encontrado"
    has_provider=true
  fi
  
  if command -v copilot &>/dev/null; then
    success "GitHub Copilot CLI encontrado"
    has_provider=true
  fi
  
  if command -v claude &>/dev/null; then
    success "Claude Code encontrado"
    has_provider=true
  fi
  
  if command -v codex &>/dev/null; then
    success "Codex CLI encontrado"
    has_provider=true
  fi
  
  if command -v gemini &>/dev/null; then
    success "Gemini CLI encontrado"
    has_provider=true
  fi
  
  if [ -n "$OPENAI_API_KEY" ]; then
    success "OpenAI API key configurada"
    has_provider=true
  fi
  
  if [ -n "$GEMINI_API_KEY" ]; then
    success "Gemini API key configurada"
    has_provider=true
  fi
  
  if command -v ollama &>/dev/null; then
    success "Ollama encontrado"
    has_provider=true
  fi
  
  if [ "$has_provider" = false ]; then
    echo ""
    warn "Nenhum provedor de IA encontrado!"
    echo ""
    echo "Instale pelo menos um dos seguintes:"
    echo "  • amp CLI: https://ampcode.com"
    echo "  • OpenAI: Configure OPENAI_API_KEY"
    echo "  • Gemini: Configure GEMINI_API_KEY (https://aistudio.google.com/apikey)"
    echo "  • Ollama: https://ollama.ai"
    echo "  • Cursor CLI: curl https://cursor.com/install -fsS | bash"
    echo "  • GitHub Copilot CLI: npm install -g @github/copilot"
    echo "  • Claude Code: npm install -g @anthropic-ai/claude-code"
    echo "  • Codex CLI: npm install -g @openai/codex"
    echo "  • Gemini CLI: npm install -g @google/gemini-cli"
    echo ""
    
    # Se está via pipe, não pode ler input, então continua
    if is_piped; then
      warn "Continuando instalação (modo não-interativo)..."
    else
      echo -e "${YELLOW}Deseja continuar a instalação mesmo assim? [s/N]${NC}"
      read -r -n 1 response
      echo ""
      if [[ ! $response =~ ^[Ss]$ ]]; then
        exit 1
      fi
    fi
  fi
}

# Cria diretório de instalação
create_install_dir() {
  if [ ! -d "$INSTALL_DIR" ]; then
    info "Criando diretório de instalação: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
  fi
}

# Instala o script (baixa do GitHub ou copia local)
install_script() {
  local target_file="$INSTALL_DIR/$SCRIPT_NAME"
  
  if is_piped; then
    # Instalação remota: baixa do GitHub
    info "Baixando $SCRIPT_NAME do GitHub..."
    
    if ! curl -fsSL "$REPO_RAW_URL/bin/commitia" -o "$target_file"; then
      error "Não foi possível baixar o script. Verifique sua conexão."
    fi
  else
    # Instalação local: copia do diretório
    local script_dir
    script_dir=$(get_script_dir)
    local source_file="$script_dir/bin/commitia"
    
    if [ ! -f "$source_file" ]; then
      # Tenta baixar do GitHub como fallback
      info "Arquivo local não encontrado, baixando do GitHub..."
      if ! curl -fsSL "$REPO_RAW_URL/bin/commitia" -o "$target_file"; then
        error "Não foi possível baixar o script. Verifique sua conexão."
      fi
    else
      info "Instalando $SCRIPT_NAME em $INSTALL_DIR..."
      cp "$source_file" "$target_file"
    fi
  fi
  
  chmod +x "$target_file"
  success "Script instalado com sucesso"
}

# Verifica se o diretório está no PATH
check_path() {
  if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    warn "$INSTALL_DIR não está no seu PATH"
    echo ""
    echo "Adicione ao seu arquivo de configuração do shell:"
    echo ""
    
    local shell_name
    shell_name=$(basename "$SHELL")
    
    case "$shell_name" in
      bash)
        echo -e "  ${CYAN}echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc${NC}"
        echo -e "  ${CYAN}source ~/.bashrc${NC}"
        ;;
      zsh)
        echo -e "  ${CYAN}echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc${NC}"
        echo -e "  ${CYAN}source ~/.zshrc${NC}"
        ;;
      fish)
        echo -e "  ${CYAN}fish_add_path $INSTALL_DIR${NC}"
        ;;
      *)
        echo -e "  ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        ;;
    esac
    echo ""
  fi
}

# Cria arquivo de configuração de exemplo
create_config_example() {
  local config_example="$HOME/.commitiarc.example"
  
  cat > "$config_example" << 'EOF'
# Configuração do CommitIA
# Copie este arquivo para ~/.commitiarc

# Provedor de IA (amp, openai, gemini, ollama, cursor, copilot, claude, codex, gemini-cli)
# COMMITIA_PROVIDER="amp"

# Idioma das mensagens (pt, en, es)
# COMMITIA_LANGUAGE="pt"

# Adicionar arquivos ao stage automaticamente
# COMMITIA_AUTO_STAGE="true"
EOF

  info "Arquivo de configuração de exemplo criado em $config_example"
}

# Mostra instruções finais
show_success() {
  echo ""
  echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║           CommitIA instalado com sucesso! 🎉               ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${BOLD}Como usar:${NC}"
  echo ""
  echo -e "  ${CYAN}commitia${NC}                     # Commit de todas as alterações"
  echo -e "  ${CYAN}commitia src/${NC}                # Commit apenas da pasta src/"
  echo -e "  ${CYAN}commitia -m \"contexto\"${NC}       # Com contexto adicional"
  echo -e "  ${CYAN}commitia -i${NC}                  # Modo interativo"
  echo -e "  ${CYAN}commitia --help${NC}              # Ver todas as opções"
  echo -e "  ${CYAN}commitia --update${NC}            # Atualizar para última versão"
  echo ""
  echo -e "${BOLD}Configuração:${NC}"
  echo ""
  echo "  Copie ~/.commitiarc.example para ~/.commitiarc e ajuste conforme necessário."
  echo ""
}

# Main
main() {
  print_banner
  
  echo -e "${BOLD}Iniciando instalação...${NC}"
  echo ""
  
  check_dependencies
  echo ""
  
  create_install_dir
  install_script
  create_config_example
  check_path
  show_success
}

main "$@"
