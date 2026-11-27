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

#### Opção 4: CLIs de IA (Cursor, Copilot, Claude Code, Codex, Gemini CLI)

Cada CLI é um provedor (`cursor`, `copilot`, `claude`, `codex`, `gemini-cli`). Instale e faça login uma vez:

```bash
# Cursor
curl https://cursor.com/install -fsS | bash
cursor-agent login

# GitHub Copilot
npm install -g @github/copilot
copilot login

# Claude Code
npm install -g @anthropic-ai/claude-code
claude auth login

# Codex
npm install -g @openai/codex
codex login

# Gemini CLI (o login pessoal com conta Google foi descontinuado; use API key)
npm install -g @google/gemini-cli
export GEMINI_API_KEY="sua-chave"  # https://aistudio.google.com/apikey
```

Depois use, por exemplo: `commitia --provider claude`.

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

### Windows (PowerShell / CMD, sem WSL)

O CommitIA roda no Windows puro usando o Git Bash que vem com o [Git para Windows](https://git-scm.com/download/win). Um pequeno atalho (`installer/commitia.cmd`) chama o mesmo script bash (`bin/commitia`), então o comando `commitia` funciona igual no PowerShell, no CMD e no Git Bash.

**Pelo instalador** (recomendado, não exige administrador):

1. Instale o [Inno Setup 6 ou superior](https://jrsoftware.org/isinfo.php).
2. Gere o instalador (a versão sai de `VERSION` em `bin/commitia`):

   ```powershell
   & "C:\Program Files\Inno Setup 7\ISCC.exe" /DAppVersion=1.0.16 installer\commitia.iss
   ```

   (o caminho muda conforme a versão instalada, ex.: `Inno Setup 6`). O resultado fica em `dist\commitia-setup.exe`.
3. Execute `dist\commitia-setup.exe`. Ele instala em `%LOCALAPPDATA%\commitia`, adiciona a pasta ao PATH do usuário e grava `COMMITIA_GIT_BASH`. Se o Git não existir, oferece instalar com o `winget`.
4. Abra um **novo** terminal e teste:

   ```powershell
   commitia --version
   commitia --config provider copilot
   ```

O arquivo de configuração global fica em `%USERPROFILE%\.commitiarc` (o mesmo `~/.commitiarc` do Git Bash) e pode ser editado no Bloco de Notas: finais de linha CRLF são aceitos.

> `bash.exe` em `C:\Windows\System32` é o WSL e não é usado. O atalho procura sempre o Git Bash (ou o caminho em `COMMITIA_GIT_BASH`).

Para rodar os testes no Windows: `& "C:\Program Files\Git\bin\bash.exe" tests/run_tests.sh`.

### Windows (WSL)

O CommitIA também funciona no Windows através do WSL (Windows Subsystem for Linux).

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

Após a instalação, configure o CommitIA. O jeito mais rápido é pela linha de comando (macOS, Linux e Windows):

```bash
commitia --config provider copilot   # define o provedor de IA (global)
commitia --config                    # lista a configuração efetiva
```

Veja todas as opções em "Configuração pela linha de comando" no README. Se preferir editar o arquivo à mão:

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

### "Não foi possível gerar a mensagem de commit" com uma CLI de IA

Normalmente a CLI não está autenticada. Veja a resposta bruta no log gravado em `.commitia/logs/` e faça login (`cursor-agent login`, `copilot login`, `claude auth login`, `codex login`). Para `gemini-cli`, defina `GEMINI_API_KEY`.

### Erros com lockfiles ou arquivos muito grandes (pnpm-lock, package-lock, yarn.lock...)

O CommitIA já trata esses casos sozinho: commita primeiro os arquivos pequenos e depois cada arquivo grande em commit separado. Se a IA falhar com o diff completo, ele usa um fallback (nome, linhas alteradas e contexto resumido) e, por último, uma mensagem padrão (`chore(deps): atualiza <lockfile>`). Ajuste a detecção no `.commitiarc`:

```bash
COMMITIA_LARGE_FILES="true"          # false desativa o tratamento
COMMITIA_LARGE_FILE_LINES="1000"     # linhas alteradas (0 desativa)
COMMITIA_LARGE_FILE_BYTES="100000"   # bytes do diff/binário (0 desativa)
COMMITIA_LARGE_FILE_PATTERNS="pnpm-lock.yaml yarn.lock *.lock"  # globs; substitui a lista padrão
```

Veja os detalhes na seção "Arquivos grandes" do [README](../README.md).

### Permissão negada

```bash
chmod +x ~/.local/bin/commitia
```

## Suporte

Se encontrar problemas, abra uma issue em:
https://github.com/chamizotec/commitia/issues
