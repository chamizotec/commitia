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
- 🤖 **Múltiplos provedores de IA** - Compatível com amp CLI, OpenAI e Ollama
- 🎨 **Interface amigável** - Cores, feedback claro e modo interativo
- ⚡ **Rápido e leve** - Script bash sem dependências pesadas

## 📦 Instalação

### Método rápido (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/seu-usuario/commitia/main/install.sh | bash
```

### Instalação manual

```bash
# Clone o repositório
git clone https://github.com/seu-usuario/commitia.git
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

### Arquivo de configuração

Crie `~/.commitiarc`:

```bash
# Provedor de IA (amp, openai, ollama)
COMMITIA_PROVIDER="amp"

# Idioma das mensagens (pt, en, es)
COMMITIA_LANGUAGE="pt"

# Adicionar arquivos ao stage automaticamente
COMMITIA_AUTO_STAGE="true"
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

### Ollama

Instale o [Ollama](https://ollama.ai) e baixe um modelo:

```bash
ollama pull codellama
commitia --provider ollama
```

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
git clone https://github.com/seu-usuario/commitia.git
cd commitia

# Teste localmente
./bin/commitia --help

# Execute os testes
./tests/run_tests.sh
```

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
