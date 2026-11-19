# Contratos de dados e de código

Este documento é a fonte da verdade para o formato dos dados e para as interfaces entre as partes do jogo. Qualquer agente ou pessoa que escreva código ou dados deve seguir estes formatos. Se precisar mudar algo, altere aqui primeiro.

## Autoloads (singletons globais)

| Nome | Arquivo | Responsabilidade |
|---|---|---|
| `CaseManager` | `scripts/core/case_manager.gd` | Carregar casos JSON, listar casos, registrar pistas encontradas |
| `CharacterRegistry` | `scripts/core/character_registry.gd` | Listar e buscar personagens JSON |
| `GameState` | `scripts/core/game_state.gd` | Detetive do jogador, caso atual, casos resolvidos, troca de cena |

## Cenas (caminhos fixos, use as constantes de `GameState.SCENES`)

| Cena | Arquivo | Dono |
|---|---|---|
| Menu principal | `scenes/menu.tscn` | agente UI |
| Escolha/criação de detetive | `scenes/character_select.tscn` | agente UI |
| Seleção de caso | `scenes/case_select.tscn` | agente UI |
| Investigação (3D) | `scenes/investigation.tscn` | agente investigação |
| Resultado do caso | `scenes/result.tscn` | agente investigação |

## Formato: personagem (`data/characters/<id>.json`)

```json
{
  "id": "voight",
  "nome": "Hank Voight",
  "franquia": "Chicago PD",
  "cargo": "Sargento",
  "descricao": "Líder da Unidade de Inteligência. Métodos duros, lealdade acima de tudo.",
  "cor": "#3a5a7a",
  "jogavel": true
}
```

- `franquia`: `"Chicago PD"`, `"Chicago Fire"`, `"Chicago Med"`, `"Law & Order: SVU"` ou `"Original"` (criado pelo jogador).
- `cor`: cor de destaque em hex, usada no modelo 3D placeholder.
- `jogavel`: `true` se o personagem pode ser escolhido como detetive do jogador. Personagens de crossover podem ser `false` (aparecem como suspeitos ou testemunhas).
- O campo `id` deve ser único e igual ao nome do arquivo (sem `.json`).

## Formato: caso (`data/cases/<id>.json`)

```json
{
  "id": "caso_001",
  "titulo": "Caso 001: Corrida na Michigan Avenue",
  "resumo": "Texto que aparece na seleção de caso e na abertura.",
  "local": "Michigan Avenue, Chicago",
  "ordem": 1,
  "crossover": null,
  "personagens": ["voight"],
  "pistas": [
    { "id": "pista_1", "descricao": "Texto da pista.", "posicao": [-4, 0.15, 3] }
  ],
  "suspeitos": [
    {
      "id": "suspeito_1",
      "nome": "Nome exibido",
      "personagem_id": null,
      "motivo": "Por que é suspeito (exibido ao investigar).",
      "posicao": [3, 1, -2],
      "interrogatorio": [
        { "pergunta": "Onde você estava?", "resposta": "No cinema.", "revela_pista": null },
        { "pergunta": "Conhecia a vítima?", "resposta": "Sim, era meu sócio.", "revela_pista": "pista_2" }
      ]
    }
  ],
  "solucao": {
    "culpado": "suspeito_2",
    "pistas_necessarias": ["pista_1", "pista_2"]
  }
}
```

Regras:
- `ordem`: número da fase. Define a ordem na seleção de casos.
- `crossover`: nome da franquia convidada (ex.: `"Chicago Med"`) ou `null`.
- `personagens`: lista de IDs de `data/characters/`, que aparecem no caso.
- `personagem_id` do suspeito: `null` para suspeito genérico, ou o ID de um personagem existente.
- `posicao` é `[x, y, z]` no cenário 3D. `y` de objetos no chão deve ser `0.15` (pista) ou `1.0` (pessoa).
- `revela_pista`: ID de uma pista que é liberada ao fazer essa pergunta, ou `null`.
- `solucao.culpado` deve ser o ID de um suspeito. `pistas_necessarias` lista as pistas que comprovam o caso.

## Estado do jogador (`GameState.player`)

```
{
  "nome": "Ana Costa",
  "origem": "franquia" | "criado",
  "character_id": "voight" | "",     # vazio se for criado
  "cargo": "Detetive",
  "cor": "#3a5a7a"
}
```

## API principal

- `CaseManager.load_case(path: String) -> bool`: carrega e define `current_case`, emite `case_loaded`.
- `CaseManager.list_case_ids() -> Array[String]`: IDs de todos os casos, ordenados por `ordem`.
- `CaseManager.get_case(id: String) -> Dictionary`: lê um caso sem alterar `current_case`.
- `CaseManager.mark_clue_found(clue_id)`: registra pista; emite `clue_found`. Lista em `found_clues`.
- `CharacterRegistry.list_characters() -> Array[Dictionary]`: todos os personagens.
- `CharacterRegistry.get_character(id) -> Dictionary`: personagem ou `{}`.
- `GameState.set_player(data: Dictionary)`, `GameState.has_player() -> bool`.
- `GameState.start_case(id) -> bool`: define o caso atual e carrega.
- `GameState.finish_case(solved: bool)`: registra resultado; emite `case_finished`.
- `GameState.go_to(scene_path)`: troca de cena. Use sempre as constantes de `GameState.SCENES`.

## Fluxo do jogo

Menu → Escolha de detetive → Seleção de caso → Investigação → (interrogatórios e acusação) → Resultado → Seleção de caso
