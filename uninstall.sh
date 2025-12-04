#!/usr/bin/env bash
#
# Script de desinstalação do CommitIA
#

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="${COMMITIA_INSTALL_DIR:-$HOME/.local/bin}"
SCRIPT_NAME="commitia"
CONFIG_FILE="$HOME/.commitiarc"
CONFIG_EXAMPLE="$HOME/.commitiarc.example"

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

main() {
  echo ""
  echo -e "${YELLOW}Deseja desinstalar o CommitIA? [s/N]${NC}"
  read -r -n 1 response
  echo ""
  
  if [[ ! $response =~ ^[Ss]$ ]]; then
    info "Desinstalação cancelada"
    exit 0
  fi
  
  # Remove o executável
  if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    rm "$INSTALL_DIR/$SCRIPT_NAME"
    success "Executável removido: $INSTALL_DIR/$SCRIPT_NAME"
  else
    warn "Executável não encontrado: $INSTALL_DIR/$SCRIPT_NAME"
  fi
  
  # Pergunta sobre arquivos de configuração
  if [ -f "$CONFIG_FILE" ] || [ -f "$CONFIG_EXAMPLE" ]; then
    echo ""
    echo -e "${YELLOW}Deseja remover os arquivos de configuração também? [s/N]${NC}"
    read -r -n 1 response
    echo ""
    
    if [[ $response =~ ^[Ss]$ ]]; then
      [ -f "$CONFIG_FILE" ] && rm "$CONFIG_FILE" && success "Removido: $CONFIG_FILE"
      [ -f "$CONFIG_EXAMPLE" ] && rm "$CONFIG_EXAMPLE" && success "Removido: $CONFIG_EXAMPLE"
    else
      info "Arquivos de configuração mantidos"
    fi
  fi
  
  echo ""
  success "CommitIA desinstalado com sucesso!"
  echo ""
}

main "$@"

