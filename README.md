# ChicagoPD

Jogo de investigação policial ambientado em Chicago, inspirado na série *Chicago P.D.* e no universo das franquias *One Chicago*. O jogador assume o papel de um detetive da Unidade de Inteligência e tem **48 horas de jogo** para reunir provas, interrogar suspeitos e testemunhas e fazer uma acusação. Se o tempo acabar sem acusação, o caso expira.

> Status: em desenvolvimento. A versão 2 do formato de casos está em definição (ver [`docs/DESIGN_V2.md`](docs/DESIGN_V2.md)).

## Destaques

- **Relógio de 48 horas.** Cada ação (deslocar-se, investigar, interrogar, intimar) consome tempo de jogo. Rotinas de suspeitos fazem com que horário e local importem.
- **Pistas, provas e laboratório.** Itens encontrados na cena podem ser enviados ao laboratório e liberam resultados após algumas horas.
- **Suspeitos que reagem.** Interrogatórios são coerentes com o que o jogador já descobriu.
- **Casos em JSON.** Criar uma nova fase é escrever um arquivo em `data/cases/`, sem alterar o código do jogo.
- **Personagens reutilizáveis e crossovers.** Personagens ficam em `data/characters/` com ID único e podem aparecer em vários casos.
- **Ferramentas de autoria.** Um gerador de casos com apoio de IA e um validador de dados mantêm o conteúdo consistente.

## Casos incluídos

| ID | Título |
|---|---|
| `caso_001` | Caso 001: Corrida na Michigan Avenue |
| `caso_002` | Caso 002: Fumaça no depósito da Halsted |
| `caso_003` | Caso 003: Mensagens apagadas em Lakeview |

## Tecnologia

- **Motor:** Godot 4.7 (GDScript)
- **Renderização:** GL Compatibility
- **Plataforma alvo inicial:** Web (HTML5), acessível em computador e celular
- **Desenvolvimento:** macOS (principal) e Linux

## Como executar

1. Instale o [Godot 4.7](https://godotengine.org/download/).
2. Clone o repositório:

   ```bash
   git clone https://github.com/andrehaas2005/ChicagoPD-Game.git
   cd ChicagoPD-Game
   ```

3. Abra a pasta do projeto no Godot (botão **Importar**, selecionando `project.godot`) e pressione **F5**. A cena principal é `scenes/menu.tscn`.

Na primeira abertura, o Godot importa os modelos 3D e gera a pasta `.godot/`. Ambas são arquivos gerados e estão no `.gitignore`.

## Estrutura do projeto

```
ChicagoPD/
├── project.godot        # Configuração do projeto e autoloads
├── scenes/              # Cenas (.tscn): menu, seleção de caso e personagem, investigação, resultado
├── scripts/
│   ├── core/            # Autoloads globais: CaseManager, CharacterRegistry, GameState, GameClock, CaseState
│   ├── investigation/   # Lógica da investigação: HUD, mapa, interrogatório, tribunal, acusação etc.
│   ├── ai/              # Comportamento dos suspeitos (suspect_brain.gd)
│   └── ui/              # Telas de menu e seleção
├── data/
│   ├── cases/           # Um JSON por caso
│   ├── characters/      # Personagens reutilizáveis
│   └── ambientes/       # Definição dos locais de rua
├── assets/models/       # Modelos 3D (GLB) e suas licenças (LICENCAS.md)
├── ui/                  # Tema visual da interface
├── tools/               # Validador de dados, gerador de casos e utilitário de GLB
└── docs/                # Documentação de arquitetura, contratos de dados e design
```

## Documentação

- [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md): decisões de arquitetura e estrutura de pastas.
- [`docs/CONTRATOS.md`](docs/CONTRATOS.md): formato de dados de personagens e casos (v1) e interfaces entre as partes do código.
- [`docs/DESIGN_V2.md`](docs/DESIGN_V2.md): design da versão 2 (investigação de 48 horas, pistas, laboratório, rotinas e reviravoltas).

## Ferramentas

### Validador de dados

Verifica `data/characters` e `data/cases` contra os contratos:

```bash
godot --headless --path . -s res://tools/validar_dados.gd
```

Use `-- --rascunhos` no final para validar também os rascunhos em `data/cases/rascunho/`.

### Gerador de casos

`tools/gerador_casos/gerar_caso.py` pede a um modelo da API da Anthropic um novo caso no formato v2, grava o rascunho e roda o validador. Requer a variável de ambiente `ANTHROPIC_API_KEY`:

```bash
export ANTHROPIC_API_KEY="sua-chave"
python3 tools/gerador_casos/gerar_caso.py
```

Nunca coloque a chave dentro do projeto.

### Conversor de GLB

`tools/glb_sem_quantizacao.py` converte modelos que usam `KHR_mesh_quantization` (caso de alguns modelos do 3dassets.dev) para atributos float32, pois o Godot 4.7 não importa essa extensão.

## Créditos e licenças

- Os personagens do jogo são originais ou fictícios, inspirados nas franquias. Não usam atores nem dados reais de elenco.
- Os modelos 3D em `assets/models/` são CC0 1.0 (domínio público), obtidos em [3dassets.dev](https://3dassets.dev). A lista completa de origens está em [`assets/models/LICENCAS.md`](assets/models/LICENCAS.md).
- A série *Chicago P.D.* e as franquias relacionadas pertencem aos seus respectivos detentores de direitos. Este projeto não tem afiliação com elas.
