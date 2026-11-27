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

### `.commitiaignore` (opcional, por projeto)

Na raiz de um repositório, um `.commitiaignore` controla o que o commitia adiciona sozinho e o que envia à IA. **A semântica é diferente da do `.gitignore`**:

- `+package-lock.json` → o arquivo **é commitado**, mas o diff **não vai para a IA**;
- `.env.local` (sem prefixo) → **não é adicionado automaticamente**; só entra no commit se você já fez `git add` antes.

Veja [COMMITIAIGNORE.md](COMMITIAIGNORE.md) e o modelo [`.commitiaignore.example`](../.commitiaignore.example).

## Atualização

### Automática (ao commitar)

Antes de gerar o commit, o commitia consulta (no máximo 1x por dia, timeout de 3s, silencioso offline) se há versão mais nova. Em terminal interativo ele pergunta `Deseja atualizar agora? [S/n]`; se sim, atualiza e continua o commit com a versão nova. Sem terminal interativo (pipe/CI) ou com `--dry-run`, só informa. Não roda com `--help`, `--version` e `--update`.

| Variável                               | Padrão  | Descrição                                              |
| -------------------------------------- | ------- | ------------------------------------------------------ |
| `COMMITIA_SKIP_UPDATE_CHECK`           | `false` | `true` desliga a checagem de nova versão               |
| `COMMITIA_UPDATE_CHECK_INTERVAL_HOURS` | `24`    | Intervalo mínimo entre consultas à rede (`0` = sempre) |

O cache da consulta fica em `~/.commitia/update-check`.

### Manual

```bash
commitia --update
```

Ou, a partir do clone do repositório:

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

### "a CLI '...' precisa ser atualizada"

O commitia confere, antes de gerar a mensagem, se a CLI instalada lista no `--help` as flags que ele usa (por exemplo, `--mode` no `cursor-agent`). Se faltar alguma, atualize a CLI:

| Provedor     | Capacidades exigidas (principais)                         | Comando de atualização                                                  |
| ------------ | --------------------------------------------------------- | ----------------------------------------------------------------------- |
| `cursor`     | `--print`, `--output-format`, `--mode`                    | `cursor-agent update`                                                   |
| `copilot`    | `--prompt`, `--silent`, `--deny-tool`, `--no-ask-user`    | `npm install -g @github/copilot@latest` (ou `copilot update`)           |
| `claude`     | `--print`, `--tools`, `--strict-mcp-config`               | `npm install -g @anthropic-ai/claude-code@latest` (ou `claude update`)  |
| `codex`      | `exec` com `--ephemeral`, `--sandbox`, `--output-last-message` | `npm install -g @openai/codex@latest` (ou `codex update`)          |
| `gemini-cli` | `--approval-mode`, `--skip-trust`, `--prompt`             | `npm install -g @google/gemini-cli@latest`                              |

A lista completa de flags por CLI está no [README](../README.md#versões-e-capacidades-exigidas-das-clis). Não há versão mínima fixa: a validação é por capacidade. O mesmo aviso aparece se a CLI responder `unknown option` em tempo de execução.

Em terminal interativo, o commitia oferece rodar esse comando para você (`Deseja atualizar agora? [S/n]`) e, se der certo, continua o commit. Sem terminal interativo ou com `--dry-run`, apenas avisa e aborta.

Para pular a validação preventiva: `export COMMITIA_SKIP_CLI_VERSION_CHECK=true` (ou no `.commitiarc`).

### Permissão negada

```bash
chmod +x ~/.local/bin/commitia
```

## Suporte

Se encontrar problemas, abra uma issue em:
https://github.com/chamizotec/commitia/issues
