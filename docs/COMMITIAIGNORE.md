# 🙈 `.commitiaignore` — guia completo

O `.commitiaignore` fica na **raiz do repositório** e controla duas coisas que o `.gitignore` não controla:

1. o que o CommitIA **adiciona automaticamente** ao commit (`git add`);
2. o que o CommitIA **envia à IA** para gerar a mensagem.

> ⚠️ **A semântica é diferente da do `.gitignore`.** O Git **não** ignora nada por causa deste arquivo: os arquivos continuam sendo rastreados normalmente e podem ser commitados com `git add` / `git commit`. O `.commitiaignore` só altera o comportamento da ferramenta `commitia`.

Se o arquivo não existir, nada muda: o comportamento é exatamente o de antes.

## Resumo rápido

| Entrada no arquivo     | Vai no commit?                                                  | Diff vai para a IA?                          |
| ---------------------- | --------------------------------------------------------------- | -------------------------------------------- |
| `+package-lock.json`   | ✅ Sim, normalmente (entra no `git add` automático)              | ❌ **Não**                                    |
| `.env.local`           | ❌ **Não** é adicionado automaticamente — só se você já fez `git add` | ✅ Sim, se você o colocou no stage (escolha sua) |
| `segredo.dat` **e** `+segredo.dat` | ❌ Não é adicionado automaticamente (só se staged por você) | ❌ Não (a regra `+` sempre vale para a IA)   |

## Formato

- Uma entrada por linha.
- Linhas vazias são ignoradas; linhas que começam com `#` são comentários.
- Espaços no início e no fim da linha são removidos (finais de linha CRLF são aceitos).
- Prefixo `+` (colado ou seguido de espaços): **commitar, mas não enviar à IA**.
- Sem prefixo: **não adicionar automaticamente**.
- Para um arquivo cujo nome começa com `#` ou `+`, escape com `\` (`\#nome`, `\+nome`).
- Negação (`!padrão`) **não é suportada** (a linha é ignorada com um aviso).

### Padrões (glob, parecidos com o `.gitignore`)

Os caminhos são relativos à raiz do repositório e **diferenciam maiúsculas de minúsculas**.

| Padrão          | Casa com                                                                                          |
| --------------- | ------------------------------------------------------------------------------------------------- |
| `nome.txt`      | `nome.txt` na raiz **ou em qualquer pasta** (e, se for uma pasta, tudo dentro dela)               |
| `*.lock`        | qualquer arquivo terminado em `.lock`, em qualquer pasta                                          |
| `?`             | um caractere (exceto `/`): `f?.txt` casa `f1.txt`                                                 |
| `[abc]` `[!a]`  | classe de caracteres (e sua negação)                                                              |
| `docs/*.md`     | `/` no **meio** ancora o padrão na raiz: casa `docs/a.md`, não `docs/x/a.md` nem `app/docs/a.md`  |
| `/arquivo.txt`  | `/` no **início** ancora na raiz: casa só `arquivo.txt` da raiz                                   |
| `build/`        | `/` no **fim** casa só diretórios: tudo dentro de qualquer pasta `build/`                         |
| `dir/**`        | tudo dentro de `dir/` (em qualquer profundidade), a partir da raiz                                |
| `**/gen/*.js`   | `*.js` dentro de qualquer pasta `gen/`, em qualquer profundidade                                  |
| `a/**/b`        | `a/b`, `a/x/b`, `a/x/y/b`...                                                                      |

`*` e `?` nunca atravessam `/`; use `**` para isso.

## Semântica 1 — `+arquivo`: commitado, mas fora da IA

```gitignore
# O lockfile entra no commit, mas a IA não "lê" as milhares de linhas dele
+package-lock.json
+pnpm-lock.yaml
+*.lock
+dist/**
```

- O arquivo é adicionado pelo `git add` automático e **entra no mesmo commit** dos demais arquivos.
- O diff dele **não é enviado à IA** — nem no diff completo, nem no resumo de fallback, nem em nenhum provedor (amp, OpenAI, Gemini, Ollama, CLIs de IA).
- A IA recebe apenas uma nota com o **nome** dos arquivos omitidos, para saber que eles fazem parte do commit (ela é instruída a não inferir o conteúdo). O conteúdo e as contagens de linhas nunca são enviados.
- Arquivos `+` **não são tratados como "arquivos grandes"**: não ganham commit separado (o tamanho deles não importa, já que a IA não os vê).
- Se **todos** os arquivos do commit forem `+`, a IA nem é chamada: o commit usa a mensagem padrão (`chore(deps): atualiza package-lock.json` para lockfiles; `chore(<escopo>): atualiza <arquivo>` nos demais, respeitando `--type`, `--scope` e o task id da branch).
- No resumo "Arquivos no stage" o CommitIA marca esses arquivos com `(commitado; conteúdo não enviado à IA)`.

## Semântica 2 — `arquivo` (sem prefixo): não commitar automaticamente

```gitignore
# Nunca entram no commit "sozinhos"
.env.local
config/local.json
scratch/**
*.key
```

- O arquivo **não é adicionado** pelo `git add` automático do CommitIA (nem com `commitia`, nem com `commitia <diretório>`), e portanto não entra no commit.
- A lista dos arquivos pulados é mostrada, para você saber o que ficou de fora.
- Se só houver arquivos assim para commitar, o CommitIA avisa e termina com erro (nada é commitado).

### Exceções (escolha explícita sua)

O arquivo **entra no commit** quando você mesmo o coloca no stage:

1. **`git add arquivo` antes de rodar `commitia`** — ele já está staged, então o CommitIA nunca o remove do stage nem o exclui do commit, e **não o re-adiciona** (se você fez `git add` de uma versão e alterou depois, o que foi commitado é a versão que estava no stage; a alteração posterior continua pendente).
2. **Passando o arquivo explicitamente**: `commitia .env.local` equivale a um `git add` manual. (Passar um **diretório**, como `commitia config/`, continua respeitando o `.commitiaignore` para os arquivos dentro dele.)

### O conteúdo staged manualmente vai para a IA?

**Sim, por padrão.** Se você escolheu explicitamente commitar o arquivo, ele é tratado como qualquer outro e o diff dele é enviado à IA — **a menos que ele também case com uma entrada `+`** (veja abaixo). Quem quer manter o arquivo sempre fora da IA, mesmo staged manualmente, deve declará-lo também com `+`.

## Precedência quando um arquivo casa com as duas regras

As duas semânticas atuam em **eixos independentes**, então não há conflito: vale a regra **mais restritiva em cada eixo**.

| Eixo                         | Quem decide                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| Adicionar ao commit (stage)  | Entrada **sem prefixo**: se o arquivo casa com ela, não é adicionado automaticamente |
| Enviar o diff à IA           | Entrada **`+`**: se o arquivo casa com ela, o diff nunca vai à IA                    |

Exemplo:

```gitignore
segredo.dat
+segredo.dat
```

- `segredo.dat` novo/alterado e **não** staged → **não** é commitado (entrada sem prefixo).
- `segredo.dat` staged por você → **é commitado**, mas o diff dele **não** vai à IA (entrada `+`).

A ordem das linhas e a quantidade de regras casando **não importam**.

## Diferenças em relação ao `.gitignore`

| | `.gitignore` | `.commitiaignore` |
| --- | --- | --- |
| Quem lê | Git | Apenas o comando `commitia` |
| Efeito | Git passa a ignorar os arquivos (não rastreados) | Nada é ignorado pelo Git; muda só o que o commitia faz |
| Entrada sem prefixo | Ignora o arquivo | **Não adiciona automaticamente** (mas entra se já estiver staged) |
| Prefixo `+` | — | **Commita normalmente, mas não envia à IA** |
| Prefixo `!` | Desfaz uma regra | Não suportado |
| Arquivos já rastreados | Não são afetados | Alterações não staged também não são adicionadas automaticamente (sem prefixo) |
| Arquivos staged manualmente | — | Sempre preservados no commit |

## Exemplos completos

```gitignore
# .commitiaignore

# 1) Entram no commit, mas a IA não os analisa (ruído / arquivos enormes)
+package-lock.json
+pnpm-lock.yaml
+yarn.lock
+*.min.js
+dist/**
+**/__snapshots__/**

# 2) Nunca commitar automaticamente (só com 'git add' explícito)
.env.local
.env.*.local
*.pem
notas-pessoais.md
tmp/
```

Fluxo típico:

```bash
# Alterados: src/app.ts, package-lock.json, .env.local
commitia
#  → commit com src/app.ts e package-lock.json (a IA só vê o diff de src/app.ts)
#  → .env.local fica de fora (avisado na saída)

# Quer mesmo commitar o .env.local?
git add .env.local
commitia
#  → o .env.local vai no commit, e o diff dele é enviado à IA (a não ser que haja '+.env.local')
```

## Observações

- O arquivo `.commitiaignore` é lido a cada execução, na raiz do repositório Git (mesmo rodando de uma subpasta). Faça commit dele para compartilhar as regras com o time.
- Existe um modelo em [`.commitiaignore.example`](../.commitiaignore.example).
- `--no-stage` continua valendo: nesse modo o CommitIA nunca adiciona nada, e as regras `+` ainda mantêm o diff fora da IA.
- Com `--amend`, as regras `+` também valem para o diff enviado à IA.
