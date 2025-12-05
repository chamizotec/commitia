# 📦 Guia de Instalação Detalhado

Este guia fornece instruções detalhadas para instalar o CommitIA em diferentes sistemas operacionais.

## Pré-requisitos

### Obrigatórios

- **Git** (versão 2.0 ou superior)
- **Bash** (versão 4.0 ou superior)

### Provedor de IA (pelo menos um)

Você precisa de pelo menos um provedor de IA configurado:

#### Opção 1: amp CLI (Recomendado)

O amp CLI é o provedor padrão e mais fácil de configurar.

```bash
# Instale seguindo as instruções em:
# https://ampcode.com
```

#### Opção 2: OpenAI

```bash
# Configure sua API key
export OPENAI_API_KEY="sk-sua-chave-aqui"

# Adicione ao seu ~/.bashrc ou ~/.zshrc para persistir
echo 'export OPENAI_API_KEY="sk-sua-chave-aqui"' >> ~/.bashrc
```

#### Opção 3: Ollama (Local, gratuito)

```bash
# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.ai/install.sh | sh

# Baixe um modelo
ollama pull codellama
```

## Instalação

### macOS / Linux

#### Instalação Rápida

```bash
curl -fsSL https://raw.githubusercontent.com/chamizotec/commitia/main/install.sh | bash
```

#### Instalação Manual

```bash
# Clone o repositório
git clone https://github.com/chamizotec/commitia.git
cd commitia

# Execute o instalador
./install.sh
```

#### Instalação Personalizada

```bash
# Instalar em diretório customizado
COMMITIA_INSTALL_DIR=/usr/local/bin ./install.sh
```

### Windows (WSL)

O CommitIA funciona no Windows através do WSL (Windows Subsystem for Linux).

1. Instale o WSL:

   ```powershell
   wsl --install
   ```

2. Abra o terminal WSL e siga as instruções de instalação para Linux.

## Configuração do PATH

Se o instalador avisar que `~/.local/bin` não está no PATH:

### Bash

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Zsh

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Fish

```fish
fish_add_path ~/.local/bin
```

## Verificando a Instalação

```bash
# Verifica se está instalado
commitia --version

# Verifica ajuda
commitia --help
```

## Configuração Inicial

Após a instalação, configure o CommitIA:

```bash
# Copie o arquivo de exemplo
cp ~/.commitiarc.example ~/.commitiarc

# Edite conforme necessário
nano ~/.commitiarc
```

## Atualização

Para atualizar para a versão mais recente:

```bash
cd /path/to/commitia
git pull
./install.sh
```

## Desinstalação

```bash
./uninstall.sh
```

Ou manualmente:

```bash
rm ~/.local/bin/commitia
rm ~/.commitiarc  # opcional
```

## Solução de Problemas

### "command not found: commitia"

Verifique se `~/.local/bin` está no PATH:

```bash
echo $PATH | grep -o '.local/bin'
```

### "amp CLI não encontrado"

Instale o amp CLI ou configure outro provedor:

```bash
# Ou use OpenAI
export OPENAI_API_KEY="sua-chave"
commitia --provider openai
```

### Permissão negada

```bash
chmod +x ~/.local/bin/commitia
```

## Suporte

Se encontrar problemas, abra uma issue em:
https://github.com/chamizotec/commitia/issues
