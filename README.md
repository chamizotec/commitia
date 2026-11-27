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
- 📦 **Arquivos grandes sem dor de cabeça** - Lockfiles (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`...) e diffs enormes são commitados separadamente, com fallback automático quando a IA falha
- 🙈 **`.commitiaignore`** - Controle o que o commitia adiciona sozinho e o que ele envia à IA (semântica própria, **diferente do `.gitignore`**; veja [a seção abaixo](#-commitiaignore-controle-o-que-é-commitado-e-o-que-vai-para-a-ia))
- 🧠 **Skill para agentes de IA** - `commitia skill` ensina Cursor, VS Code/Copilot e Claude Code a usar o commitia nos commits
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
| `--update`              | Atualiza para a versão mais recente   |
| `--force`               | Reinstala mesmo na versão atual (com `--update`) |
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
4. **Padrão** (menor prioridade): amp, pt, true (arquivos grandes: 1000 linhas / 100000 bytes)

### Configuração global

Crie `~/.commitiarc`:

```bash
# Provedor de IA (amp, openai, gemini, ollama, cursor, copilot, claude, codex, gemini-cli)
COMMITIA_PROVIDER="amp"

# Idioma das mensagens (pt, en, es)
COMMITIA_LANGUAGE="pt"

# Adicionar arquivos ao stage automaticamente
COMMITIA_AUTO_STAGE="true"

# Arquivos grandes (lockfiles e diffs enormes) em commits separados
COMMITIA_LARGE_FILES="true"
COMMITIA_LARGE_FILE_LINES="1000"
COMMITIA_LARGE_FILE_BYTES="100000"
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

### Atualização automática do commitia

Antes de gerar o commit, o CommitIA confere se existe uma versão **mais nova** (comparação numérica: `1.0.10` > `1.0.9`). Se existir, ele avisa e pergunta:

```
ℹ Nova versão 1.0.16 disponível (você está na 1.0.15)
Deseja atualizar agora? [S/n]
```

- **Sim** (ou Enter): atualiza o binário e continua o commit já com a versão nova (o commitia é reexecutado com os mesmos argumentos). Se a atualização falhar, avisa e segue com a versão atual.
- **Não**: segue com a versão atual (o aviso volta enquanto houver versão pendente).
- **Sem terminal interativo** (pipe/CI): apenas informa a nova versão e segue; nada é alterado.
- **`--dry-run`**: apenas informa a nova versão, sem perguntar e sem alterar o binário.
- Não roda com `--help`, `--version` e `--update`. Offline, a consulta (timeout de 3s) falha em silêncio.
- Rodando a partir de um clone do repositório (pasta com `.git`), o commitia não se sobrescreve: só informa.

O resultado da consulta fica em cache em `~/.commitia/update-check`, evitando latência de rede em todo commit.

| Variável                              | Padrão  | Descrição                                                    |
| ------------------------------------- | ------- | ------------------------------------------------------------ |
| `COMMITIA_SKIP_UPDATE_CHECK`          | `false` | `true` desliga a checagem de nova versão                     |
| `COMMITIA_UPDATE_CHECK_INTERVAL_HOURS`| `24`    | Intervalo mínimo entre consultas à rede (`0` = sempre)       |

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

#### Versões e capacidades exigidas das CLIs

Antes de gerar a mensagem, o commitia valida a CLI **por capacidade**: o `--help` precisa listar as flags abaixo. Não há versão mínima fixa (não dá para determiná-la com segurança); a versão instalada é mostrada apenas para diagnóstico. Se faltar alguma flag, o commitia aborta e informa a CLI, a versão instalada, a capacidade ausente e o comando de atualização.

| Provedor     | Flags exigidas no `--help`                                                                                                     | Atualizar                                                          | Versão testada |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------ | -------------- |
| `cursor`     | `--print` `--output-format` `--mode`                                                                                           | `cursor-agent update`                                              | 2026.01.23     |
| `copilot`    | `--prompt` `--silent` `--no-color` `--no-ask-user` `--no-custom-instructions` `--no-auto-update` `--disable-builtin-mcps` `--deny-tool` | `npm install -g @github/copilot@latest` (ou `copilot update`)      | 1.0.116        |
| `claude`     | `--print` `--tools` `--disable-slash-commands` `--strict-mcp-config` `--no-session-persistence` `--output-format`              | `npm install -g @anthropic-ai/claude-code@latest` (ou `claude update`) | 2.1.332    |
| `codex`      | (em `codex exec --help`) `--skip-git-repo-check` `--ephemeral` `--sandbox` `--color` `--output-last-message`                  | `npm install -g @openai/codex@latest` (ou `codex update`)          | 0.172.0        |
| `gemini-cli` | `--approval-mode` `--skip-trust` `--output-format` `--prompt`                                                                  | `npm install -g @google/gemini-cli@latest`                         | 0.71.1         |

Se mesmo assim a CLI responder com `unknown option`, `unrecognized option` ou similar, o commitia mostra a mesma mensagem de atualização (o log em `.commitia/logs/` mantém a saída original) e não usa o fallback de arquivos grandes para esconder o problema.

Em terminal interativo, ao detectar uma CLI desatualizada o commitia pergunta `Deseja atualizar agora? [S/n]` e roda o comando de atualização da tabela (`cursor-agent update` ou `npm install -g <pacote>@latest`). Se a atualização der certo, ele revalida a CLI e segue para gerar e aplicar o commit; se você recusar ou ela falhar, aborta com a mensagem acima. Sem terminal interativo ou com `--dry-run`, só avisa e aborta (nada é instalado).

Para pular a validação preventiva (por exemplo, com uma CLI que oculta flags no `--help`):

```bash
COMMITIA_SKIP_CLI_VERSION_CHECK="true"
```

## 📦 Arquivos grandes (lockfiles e diffs enormes)

Lockfiles e arquivos com diff muito grande costumam estourar o limite da IA. O CommitIA os identifica no stage e os commita **separadamente**, sem você precisar fazer nada manualmente.

### Como detecta

Um arquivo do stage é considerado grande se **qualquer** critério for verdadeiro:

- o nome casa com `COMMITIA_LARGE_FILE_PATTERNS` (por padrão, lockfiles conhecidos: `pnpm-lock.yaml`, `package-lock.json`, `npm-shrinkwrap.json`, `yarn.lock`, `bun.lock`, `bun.lockb`, `composer.lock`, `Cargo.lock`, `poetry.lock`, `Pipfile.lock`, `Gemfile.lock`, `go.sum`, `mix.lock`, `pubspec.lock`, `Podfile.lock`, `Package.resolved`, `flake.lock`, `deno.lock`, `uv.lock`, `pdm.lock`, `*.lock`, `*-lock.json`, `*-lock.yaml`...);
- o número de linhas alteradas (`git diff --staged --numstat`) é maior ou igual a `COMMITIA_LARGE_FILE_LINES`;
- o tamanho do diff em bytes é maior ou igual a `COMMITIA_LARGE_FILE_BYTES`;
- é um arquivo **binário** com tamanho maior ou igual a `COMMITIA_LARGE_FILE_BYTES` (binários grandes nunca têm o diff enviado à IA, apenas um resumo).

### Fluxo

1. Os arquivos **pequenos** são commitados primeiro (os grandes saem do stage temporariamente).
2. Cada arquivo **grande** é commitado em **commit próprio**. O CommitIA tenta primeiro enviar o diff completo à IA (respeitando `COMMITIA_MAX_DIFF_CHARS`).
3. Se a IA falhar (erro, timeout, resposta vazia ou inválida) e **já houve commit nesta sessão**, o **fallback** envia só o nome do arquivo, as linhas adicionadas/removidas, um contexto resumido (cabeçalhos dos hunks e uma pequena amostra) e o **último commit da sessão** — o último commit criado pelo CommitIA nesta execução (ex.: o dos arquivos pequenos). O último commit da branch **não** é usado como contexto.
4. Se o fallback também falhar, **ou se nenhum commit foi criado nesta sessão** (ex.: só há arquivos grandes), vai direto para a **mensagem padrão de último recurso**: `chore(<escopo>): atualiza <arquivo>` (lockfiles: `chore(deps): atualiza <lockfile>`), respeitando `--type`, `--scope` e o task id da branch.

As falhas intermediárias da IA continuam sendo gravadas em `.commitia/logs` (e mantidas quando o fallback resolve). Se algo falhar no meio (hook de commit, erro na IA para os arquivos pequenos, cancelamento ou Ctrl+C), os arquivos grandes ainda não commitados voltam ao stage exatamente como estavam.

### Comportamento com as opções

| Opção            | Comportamento                                                                                                     |
| ---------------- | ----------------------------------------------------------------------------------------------------------------- |
| `-d, --dry-run`  | Mostra o plano e as mensagens (inclusive do fallback) sem alterar o stage nem criar commits                       |
| `-i`             | Pergunta antes de cada commit; cancelar interrompe o fluxo e devolve os arquivos grandes ao stage                 |
| `-a, --amend`    | Não separa os arquivos (um amend altera um único commit), mas o fallback de mensagem continua ativo               |
| `arquivos...`    | Os arquivos passados são adicionados ao stage normalmente; os grandes entre eles são separados                    |

### Configuração

```bash
COMMITIA_LARGE_FILES="true"            # false desativa todo o tratamento (padrão: true)
COMMITIA_LARGE_FILE_LINES="1000"       # linhas alteradas (0 desativa o critério)
COMMITIA_LARGE_FILE_BYTES="100000"     # bytes do diff/binário (0 desativa o critério)
COMMITIA_LARGE_FILE_PATTERNS="pnpm-lock.yaml yarn.lock *.lock docs/*.generated.json"  # substitui a lista padrão
```

Os padrões são globs separados por espaço ou vírgula e comparados com o nome do arquivo e com o caminho completo. Defina `COMMITIA_LARGE_FILE_PATTERNS=""` para desativar a detecção por nome.

## 🙈 `.commitiaignore`: controle o que é commitado e o que vai para a IA

> ⚠️ **Atenção: a semântica NÃO é a do `.gitignore`.** O Git não ignora nada por causa deste arquivo. Ele só muda o que o **commitia** faz: o que adiciona ao commit (`git add` automático) e o que envia à IA.

Crie um arquivo `.commitiaignore` na **raiz do repositório** (opcional; sem ele, nada muda). Uma entrada por linha; linhas vazias e comentários (`#`) são ignorados; aceita globs parecidos com os do `.gitignore` (`*.lock`, `dir/**`, `**/gen/*.js`, `build/`, `/raiz.txt`...).

| Entrada                | O arquivo é commitado?                                                         | O diff vai para a IA?                                   |
| ---------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------- |
| `+package-lock.json` (prefixo `+`) | ✅ **Sim**, normalmente (entra no `git add` automático e no mesmo commit) | ❌ **Não**: o conteúdo/diff nunca é enviado             |
| `.env.local` (sem prefixo)         | ❌ **Não é adicionado automaticamente**; entra **só se você já fez `git add`** | ✅ Sim, se você o colocou no stage (escolha explícita sua) |

```gitignore
# .commitiaignore

# Entram no commit, mas a IA não os analisa (lockfiles, artefatos gerados...)
+package-lock.json
+pnpm-lock.yaml
+dist/**

# Nunca commitados "sozinhos": só com `git add` explícito antes do commitia
.env.local
*.pem
tmp/
```

**Como funciona**

- **`+arquivo`**: commitado junto com os demais arquivos, mas fora da análise da IA (nem o diff completo, nem o resumo de fallback). A IA só recebe uma nota com o **nome** do arquivo omitido. Esses arquivos não são tratados como "arquivos grandes" (não ganham commit separado). Se **todos** os arquivos do commit forem `+`, a IA nem é chamada e vale a mensagem padrão (`chore(deps): atualiza package-lock.json`).
- **`arquivo`** (sem prefixo): o `git add` automático **pula** o arquivo (a saída lista o que ficou de fora). Se você fizer `git add arquivo` **antes** de rodar o `commitia`, ele **entra no commit**, nunca é removido do stage e o diff **vai à IA** como o de qualquer arquivo (você escolheu commitá-lo). Passar o arquivo explicitamente (`commitia .env.local`) equivale a um `git add` manual; passar um diretório continua respeitando o `.commitiaignore`.
- **Precedência**: os dois tipos de regra atuam em eixos independentes. Se um arquivo casar com `arquivo` **e** com `+arquivo`, ele não é adicionado automaticamente (regra sem prefixo) e, se você o colocar no stage, é commitado mas **nunca** enviado à IA (regra `+`). A ordem das linhas não importa.

Detalhes completos (tabela de padrões, comparação com o `.gitignore`, exemplos): [docs/COMMITIAIGNORE.md](docs/COMMITIAIGNORE.md). Modelo pronto: [`.commitiaignore.example`](.commitiaignore.example). Também descrito em `commitia --help`.

## 🧠 Skill para agentes de IA

O comando `commitia skill` gera uma [Agent Skill](https://agentskills.io) (`SKILL.md`) que explica os recursos do CommitIA para o agente de IA do seu editor. Assim, quando você pedir "faça o commit", o agente usa o `commitia` (com stage explícito, `--no-stage`, `--dry-run`, tratamento de erros etc.) em vez de escrever a mensagem por conta própria.

```bash
# Escolhe o destino de forma interativa
commitia skill

# Instala no projeto atual
commitia skill cursor
commitia skill vscode
commitia skill copilot
commitia skill claude

# Instala para o seu usuário (vale para todos os projetos)
commitia skill cursor --global

# Apenas gera o arquivo, para incluir onde preferir
commitia skill file                       # grava ./commitia-skill.md
commitia skill file -o docs/ia/SKILL.md   # caminho customizado
commitia skill file -o -                  # imprime na tela
```

| Destino   | Projeto                                 | Global (`--global`)                  |
| --------- | --------------------------------------- | ------------------------------------ |
| `cursor`  | `.cursor/skills/commitia/SKILL.md`      | `~/.cursor/skills/commitia/SKILL.md` |
| `vscode`  | `.github/skills/commitia/SKILL.md`      | `~/.copilot/skills/commitia/SKILL.md` |
| `copilot` | `.github/skills/commitia/SKILL.md`      | `~/.copilot/skills/commitia/SKILL.md` |
| `claude`  | `.claude/skills/commitia/SKILL.md`      | `~/.claude/skills/commitia/SKILL.md` |
| `file`    | `./commitia-skill.md` (ou `-o <caminho>`) | -                                    |

- Em um repositório Git, a pasta do projeto é a raiz do repositório (mesmo rodando de uma subpasta).
- É possível informar vários destinos de uma vez: `commitia skill cursor copilot`.
- Se já existir uma skill diferente no destino, o commitia não sobrescreve; use `--force`. Se for idêntica, nada é alterado. Ao atualizar o commitia, rode `commitia skill <destino> --force` para renovar a skill.
- `--dry-run` mostra onde a skill seria gravada, sem criar arquivos.
- `skill` só é tratado como subcomando quando é o **primeiro** argumento; para commitar um arquivo chamado `skill`, use `commitia ./skill`.

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
