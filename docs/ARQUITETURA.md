# Arquitetura do ChicagoPD

Documento de referência da estrutura do projeto. Atualize-o sempre que uma decisão de arquitetura mudar.

## Stack

- **Motor:** Godot 4.7 (GDScript)
- **Renderização:** GL Compatibility (necessária para exportar para web)
- **Plataforma inicial:** Web (HTML5), acessível em PC e celular via URL privada
- **Sistemas:** macOS (desenvolvimento atual) e Linux (máquina secundária)

## Estrutura de pastas

```
ChicagoPD/
├── project.godot          # Configuração do projeto
├── scenes/                # Cenas (.tscn): fases, cidade, delegacia, interface
├── scripts/
│   ├── core/              # Autoloads globais (CaseManager etc.)
│   └── main.gd            # Cena de teste atual
├── data/
│   ├── cases/             # Um arquivo JSON por caso/fase
│   └── characters/        # Personagens reutilizáveis (crossovers)
└── docs/                  # Documentação
```

## Decisões principais

### 1. Casos em JSON, separados do código
Cada caso é um arquivo em `data/cases/`. Assim, criar uma nova fase é escrever um JSON, sem mexer na lógica do jogo. O `CaseManager` (autoload) faz a leitura.

Estrutura de um caso:
- `titulo`, `resumo`, `local`
- `crossover`: franquia convidada (`null` se não houver)
- `personagens`, `pistas`, `suspeitos`
- `solucao`: culpado e pistas necessárias para resolver

### 2. Personagens reutilizáveis
Personagens de crossover (médicos do *Chicago Med*, bombeiros do *Chicago Fire* etc.) ficarão em `data/characters/`, com ID único. Um caso apenas referencia o ID, sem duplicar dados.

### 3. Cenas modulares
Cada fase é uma cena própria. Elementos comuns (interrogatório, cena do crime, ficha de suspeito) serão cenas reutilizáveis.

## Próximos passos

1. Validar a cena de teste rodando no editor.
2. Criar o sistema de interação com o cenário (clicar em pistas).
3. Criar o fluxo de interrogatório.
4. Configurar a exportação para web (instalar os templates de exportação do Godot).
5. Publicar em URL privada.
