# Contribuindo para o CommitIA

Primeiramente, obrigado por considerar contribuir com o CommitIA! 🎉

## 📋 Código de Conduta

Este projeto adota um Código de Conduta que esperamos que todos os participantes sigam. Por favor, seja respeitoso e construtivo em todas as interações.

## 🐛 Reportando Bugs

Antes de criar um issue:

1. Verifique se o bug já não foi reportado
2. Tente reproduzir o bug na versão mais recente
3. Colete informações sobre seu ambiente

Ao criar o issue, inclua:

- Versão do CommitIA (`commitia --version`)
- Sistema operacional e versão
- Provedor de IA utilizado
- Passos para reproduzir o bug
- Comportamento esperado vs. comportamento atual
- Logs de erro (se houver)

## 💡 Sugerindo Features

Adoramos novas ideias! Ao sugerir uma feature:

1. Verifique se já não existe uma sugestão similar
2. Descreva o problema que a feature resolve
3. Sugira uma possível implementação
4. Considere se a feature beneficia a maioria dos usuários

## 🔧 Desenvolvimento

### Setup do ambiente

```bash
# Clone o repositório
git clone https://github.com/chamizotec/commitia.git
cd commitia

# O projeto é um script bash, não precisa de build
# Teste localmente:
./bin/commitia --help
```

### Estrutura do projeto

```
commitia/
├── bin/
│   └── commitia          # Script principal
├── tests/
│   └── run_tests.sh      # Testes
├── docs/
│   ├── COMMITIAIGNORE.md # Guia do .commitiaignore
│   └── ...               # Documentação adicional
├── .commitiaignore.example # Modelo de .commitiaignore
├── install.sh            # Instalador
├── uninstall.sh          # Desinstalador
├── README.md
├── CONTRIBUTING.md
└── LICENSE
```

### Padrões de código

- Use 2 espaços para indentação
- Funções devem ter nomes descritivos em snake_case
- Adicione comentários para lógica complexa
- Use `shellcheck` para validar o código:

```bash
shellcheck bin/commitia
```

### Testando

```bash
# Execute os testes
./tests/run_tests.sh

# Teste manual
./bin/commitia --dry-run
./bin/commitia --help
```

## 📝 Pull Requests

1. Fork o projeto
2. Crie uma branch para sua feature:
   ```bash
   git checkout -b feature/minha-feature
   ```
3. Faça suas alterações
4. Execute `shellcheck` e os testes
5. Commit suas alterações (use `commitia`! 😉):
   ```bash
   ./bin/commitia -m "adiciona nova feature X"
   ```
6. Push para sua branch:
   ```bash
   git push origin feature/minha-feature
   ```
7. Abra um Pull Request

### Checklist do PR

- [ ] Código segue os padrões do projeto
- [ ] `shellcheck` passa sem erros
- [ ] Testes passam
- [ ] Documentação atualizada (se necessário)
- [ ] README atualizado (se necessário)
- [ ] Mensagem de commit segue Conventional Commits

## 🏷️ Labels

Usamos as seguintes labels nos issues:

| Label              | Descrição                 |
| ------------------ | ------------------------- |
| `bug`              | Algo não está funcionando |
| `feature`          | Nova funcionalidade       |
| `docs`             | Documentação              |
| `good first issue` | Bom para iniciantes       |
| `help wanted`      | Precisamos de ajuda       |
| `question`         | Dúvidas                   |

## 🎉 Reconhecimento

Contribuidores são reconhecidos no README e nos releases. Agradecemos toda contribuição, grande ou pequena!

---

Dúvidas? Abra um issue ou entre em contato!
