# 🤖 CommitIA

> Gerador de commits inteligentes com IA seguindo o padrão Conventional Commits

CommitIA analisa suas alterações no Git e gera automaticamente mensagens de commit semânticas, seguindo as melhores práticas do [Conventional Commits](https://www.conventionalcommits.org/).

<p align="center">
  <img src="docs/demo.gif" alt="Demo do CommitIA" width="600">
</p>

## ✨ Funcionalidades

- 🎯 **Mensagens semânticas** - Segue o padrão Conventional Commits automaticamente
- 🔍 **Detecção de escopo** - Extrai automaticamente IDs de tarefas da branch (JIRA, etc.)
- 🌍 **Multi-idioma** - Suporte para português, inglês e espanhol
- 🤖 **Múltiplos provedores de IA** - Compatível com amp CLI, OpenAI, Gemini, Ollama e as CLIs do Cursor, GitHub Copilot, Claude Code, Codex e Gemini
- 🎨 **Interface amigável** - Cores, feedback claro e modo interativo
- ⚡ **Rápido e leve** - Script bash sem dependências pesadas

## 📦 Instalação

### Método rápido (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/chamizotec/commitia/refs/heads/main/install.sh | bash
```

### Instalação manual

```bash
# Clone o repositório
git clone https://github.com/chamizotec/commitia.git
cd commitia

# Execute o instalador
./install.sh
```

### Homebrew (em breve)

```bash
brew install commitia
```

## 🚀 Uso

### Uso básico

```bash
# Commit de todas as alterações
commitia

# Commit de arquivos específicos
commitia src/components/

# Com contexto adicional para a IA
commitia -m "corrige bug de autenticação"
```

### Opções avançadas

```bash
# Modo interativo (confirma antes de commitar)
commitia -i

# Dry-run (apenas mostra a mensagem)
commitia -d

# Força um tipo específico
commitia -t fix

# Define o escopo manualmente
commitia -s auth

# Combinando opções
commitia -t feat -s api -m "implementa novo endpoint"

# Altera o último commit
commitia -a
```

### Todas as opções

| Opção                   | Descrição                             |
| ----------------------- | ------------------------------------- |
| `-m, --message <texto>` | Contexto adicional para a mensagem    |
| `-t, --type <tipo>`     | Força um tipo de commit específico    |
| `-s, --scope <escopo>`  | Define o escopo manualmente           |
| `-i, --interactive`     | Modo interativo                       |
| `-d, --dry-run`         | Apenas mostra a mensagem              |
| `-a, --amend`           | Altera o último commit                |
| `--no-stage`            | Não adiciona arquivos automaticamente |
| `--provider <provider>` | Define o provedor de IA               |
| `--lang <idioma>`       | Idioma da mensagem (pt, en, es)       |
| `-v, --version`         | Mostra a versão                       |
| `-h, --help`            | Mostra ajuda                          |

## 📝 Tipos de Commit

| Tipo       | Descrição                     |
| ---------- | ----------------------------- |
| `feat`     | Nova funcionalidade           |
| `fix`      | Correção de bug               |
| `docs`     | Documentação                  |
| `style`    | Formatação (não afeta código) |
| `refactor` | Refatoração                   |
| `test`     | Testes                        |
| `chore`    | Manutenção                    |
| `perf`     | Performance                   |
| `ci`       | CI/CD                         |
| `build`    | Build/dependências            |
| `revert`   | Reversão                      |

## ⚙️ Configuração

### Ordem de prioridade

1. **Linha de comando** (maior prioridade): `--provider`, `--lang`
2. **Projeto**: `.commitiarc` na raiz do repositório
3. **Global**: `~/.commitiarc`
4. **Padrão** (menor prioridade): amp, pt, true

### Configuração global

Crie `~/.commitiarc`:

```bash
# Provedor de IA (amp, openai, gemini, ollama, cursor, copilot, claude, codex, gemini-cli)
COMMITIA_PROVIDER="amp"

# Idioma das mensagens (pt, en, es)
COMMITIA_LANGUAGE="pt"

# Adicionar arquivos ao stage automaticamente
COMMITIA_AUTO_STAGE="true"
```

### Configuração por projeto

Crie `.commitiarc` na raiz do seu projeto para configurações específicas:

```bash
# Exemplo: projeto internacional em inglês usando OpenAI
COMMITIA_PROVIDER="openai"
COMMITIA_LANGUAGE="en"
```

### Variáveis de ambiente

```bash
export COMMITIA_PROVIDER="openai"
export COMMITIA_LANGUAGE="en"
export OPENAI_API_KEY="sk-..."
```

## 🤖 Provedores de IA

### amp CLI (padrão)

O [amp CLI](https://ampcode.com) é o provedor padrão. Instale seguindo as instruções do site oficial.

### OpenAI

Configure sua API key:

```bash
export OPENAI_API_KEY="sk-..."
commitia --provider openai
```

### Gemini (Google)

Obtenha uma API key em [Google AI Studio](https://aistudio.google.com/apikey) e configure:

```bash
export GEMINI_API_KEY="sua-chave"
commitia --provider gemini
```

Opcionalmente defina o modelo no `.commitiarc` ou via variável de ambiente:

```bash
COMMITIA_GEMINI_MODEL="gemini-1.5-flash"  # ou gemini-2.0-flash (padrão)
```

### Ollama

Instale o [Ollama](https://ollama.ai) e baixe um modelo:

```bash
ollama pull codellama
commitia --provider ollama
```

### CLIs de IA (Cursor, Copilot, Claude Code, Codex, Gemini CLI)

Cada CLI tem um provedor próprio. O diff é enviado no prompt e as ferramentas do agente ficam desligadas (somente leitura, sem executar comandos nem editar arquivos). Instale a CLI, faça login uma vez e use `--provider`:

| Provedor     | Instalação                                      | Login                                       |
| ------------ | ----------------------------------------------- | ------------------------------------------- |
| `cursor`     | `curl https://cursor.com/install -fsS \| bash`  | `cursor-agent login`                        |
| `copilot`    | `npm install -g @github/copilot`                | `copilot login`                             |
| `claude`     | `npm install -g @anthropic-ai/claude-code`      | `claude auth login`                         |
| `codex`      | `npm install -g @openai/codex`                  | `codex login`                               |
| `gemini-cli` | `npm install -g @google/gemini-cli`             | `export GEMINI_API_KEY="sua-chave"` (*)     |

(*) O login pessoal com conta Google do Gemini CLI foi descontinuado; use uma API key do [Google AI Studio](https://aistudio.google.com/apikey).

```bash
commitia --provider claude
commitia --provider gemini-cli
```

Variáveis opcionais (no `.commitiarc` ou no ambiente):

```bash
COMMITIA_CLI_TIMEOUT="120"        # tempo máximo (s) de espera pela CLI
COMMITIA_MAX_DIFF_CHARS="60000"   # limite de caracteres do diff enviado
COMMITIA_CLAUDE_MODEL="sonnet"    # modelo (CURSOR, COPILOT, CLAUDE, CODEX, GEMINI_CLI)
```

> O provedor `gemini` usa a API REST; `gemini-cli` usa a CLI `gemini`.

## 🔄 Integração com branches

CommitIA detecta automaticamente IDs de tarefas da sua branch:

| Branch                          | Escopo detectado |
| ------------------------------- | ---------------- |
| `feature/ENP-1234-nova-feature` | `ENP-1234`       |
| `fix/JIRA-567`                  | `JIRA-567`       |
| `bugfix/ABC123-correcao`        | `ABC123`         |

## 🛠️ Desenvolvimento

```bash
# Clone o repositório
git clone https://github.com/chamizotec/commitia.git
cd commitia

# Teste localmente
./bin/commitia --help

# Execute os testes
./tests/run_tests.sh
```

## 📌 Versão e releases

A versão fica em `bin/commitia` (variável `VERSION`). Ao fazer **push na branch `main`**, um [GitHub Action](.github/workflows/bump-version.yml) incrementa automaticamente o **patch** (ex.: `1.0.9` → `1.0.10`), faz commit e push do bump. Commits cuja mensagem já for um bump de versão são ignorados para evitar loop.

### Automação local: push + pull

Para, ao fazer push na main, já trazer o commit de bump gerado pelo CI:

**Opção 1 – Script no repositório**

```bash
./scripts/push-main.sh
```

**Opção 2 – Alias no Git (só na main)**

Inclui um delay (10s) entre push e pull para dar tempo do CI rodar:

```bash
git config alias.pushmain '!git push origin main && echo "Aguardando CI (10s)..." && sleep 10 && git pull'
```

Depois use: `git pushmain` quando estiver na branch `main`. Para outro delay, troque `sleep 10` por `sleep 15`, etc.

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor, leia o [CONTRIBUTING.md](CONTRIBUTING.md) antes de enviar um PR.

1. Fork o projeto
2. Crie sua branch (`git checkout -b feature/nova-feature`)
3. Commit suas alterações (use `commitia` 😉)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## 🙏 Agradecimentos

- [Conventional Commits](https://www.conventionalcommits.org/)
- [amp CLI](https://ampcode.com)
- Todos os contribuidores!

---

<p align="center">
  Feito com ❤️ para desenvolvedores que querem commits melhores
</p>
