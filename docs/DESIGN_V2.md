# ChicagoPD v2: investigação em 48 horas

Esta versão transforma a demonstração em um jogo de investigação de verdade: o caso dura 48 horas de jogo, o jogador precisa sair para as ruas, reunir provas, intimar testemunhas e interrogar suspeitos que reagem de forma coerente ao que ele descobre.

Este documento substitui o formato de caso de `CONTRATOS.md` (v1). Onde houver conflito, vale este documento.

## 1. Referências da série (para ambientação)

Fatos reais usados como base de ambientação, sem copiar personagens ou roteiros:

- A série é um spin-off de *Chicago Fire* e se passa no 21º Distrito, onde ficam os policiais de patrulha e a Unidade de Inteligência, que cuida de crimes graves, como crime organizado, tráfico e homicídios de repercussão. (Fonte: [Chicago P.D. no One Chicago Wiki](https://one-chicago-fbi.fandom.com/wiki/Chicago_P.D.), [Intelligence Unit no One Chicago Wiki](https://one-chicago-fbi.fandom.com/wiki/Intelligence_Unit))
- O sargento Hank Voight lidera a unidade, com métodos duros e pouca paciência com regras. Ele é o modelo de "chefe de unidade" do jogo. (Fonte: [Television Wiki](https://television.fandom.com/wiki/Chicago_P.D.))
- A unidade trabalha em dupla, com equipe de patrulha, informantes e vigilância. Os casos se resolvem por interrogatório, cruzamento de provas e trabalho de rua.
- Crossovers: o Hospital Gaylord (*Chicago Med*) e a Firehouse 51 (*Chicago Fire*) são locais recorrentes, e *Law & Order: SVU* tem uma unidade que trabalha com crimes sexuais e vítimas vulneráveis. Os crossovers usam locais e personagens das outras séries.

Os personagens do jogo são **originais ou fictícios**, inspirados nas franquias. Não usamos atores nem personagens com dados reais de elenco. (Ver seção 9 sobre uso e direitos.)

## 2. Loop de jogo

Cada caso tem uma **linha do tempo de 48 horas** (dia 1, 08:00 até dia 3, 08:00). O relógio só avança com ações:

| Ação | Tempo gasto | Onde |
|---|---|---|
| Deslocar-se para um local da rua | custo do local (30 a 120 min) | Mapa |
| Investigar um local (examinar cena, bater de porta em porta) | 60 min | Local |
| Interrogar suspeito ou testemunha | 30 min | Delegacia ou Local |
| Intimar uma testemunha (ela chega à delegacia depois) | 120 min | Delegacia |
| Enviar prova ao laboratório | 0 min, mas o resultado chega após N horas | Delegacia |
| Ler resultado do laboratório | 0 min | Delegacia |
| Acusar | encerra o caso | Delegacia |

Ao chegar a 48 horas sem acusação, o caso **expira** (derrota).

**Rotinas:** suspeitos e testemunhas se movem por horários. Um suspeito pode estar em um local de rua apenas entre 08:00 e 12:00 do dia 2. O jogador precisa chegar no horário certo para encontrá-lo.

**Reviravoltas:** eventos programados no tempo. Ex.: "às 26h, a perícia confirma que o cofre foi aberto por dentro", liberando uma pista nova com mensagem de plantão.

## 3. Pistas, provas e laboratório

- **Pista:** algo visto no local. Entra no inventário ao ser coletada (clique), sem custo extra.
- **Prova:** pista que passou pelo laboratório. Pode ser usada para confrontar suspeitos (ver seção 4).
- **Laboratório:** a pista é enviada, e após `tempo_horas` o resultado é liberado com uma `conclusao` (pode revelar nova pista ou confirmar uma hipótese).

## 4. Suspeitos e testemunhas: a "inteligência"

Cada suspeito ou testemunha é um agente com **estado interno**:

- **Atitude:** `calmo`, `nervoso`, `arrogante` ou `agressivo`. Define o tom das respostas base.
- **Pressão:** número que sobe a cada pergunta agressiva ou confronto com prova, e desce com perguntas empáticas. Quando passa do `limiar_pressao`, o suspeito revela um segredo.
- **Alibi:** versão declarada do paradeiro. Pode ser **falso**, e a falsidade é exposta por uma `pista` ou por outro suspeito.
- **Segredos:** informações ocultas, cada uma com as provas que as revelam.
- **Confronto:** o jogador pode apresentar uma prova durante o interrogatório. A resposta muda se a prova contradiz o que o suspeito disse antes.

Respostas são escolhidas por regras, não geradas em tempo real, então o jogo funciona offline e no navegador sem chave de API. O motor de geração de casos (seção 5) escreve esses dados, e o jogo apenas os segue. Uma integração opcional com a API pode vir depois, por um servidor próprio, para não expor chaves no navegador.

## 5. Gerador de casos com IA

Ferramenta offline, fora do jogo, em `tools/gerador_casos/`:

1. Recebe um tema (ex.: "crime em Wicker Park envolvendo uma loja de penhores"), a franquia de crossover e a quantidade de suspeitos.
2. Chama a API do Claude com o contrato v2 como especificação, e pede JSON estrito.
3. Salva o caso como **rascunho** em `data/cases/rascunho/`.
4. Roda `tools/validar_dados.gd`. Só move o caso para `data/cases/` depois de passar na validação.

Chave da API via variável de ambiente `ANTHROPIC_API_KEY`. Nunca gravada no projeto.

## 6. Formato de caso v2 (`data/cases/<id>.json`)

```json
{
  "id": "caso_004",
  "titulo": "Caso 004: ...",
  "resumo": "Abertura do caso, mostrada na seleção.",
  "ordem": 4,
  "crossover": "Chicago Med",
  "duracao_horas": 48,
  "personagens": ["reyes", "castellano"],
  "locais": [
    { "id": "delegacia", "nome": "Delegacia do 21º Distrito", "tipo": "delegacia" },
    { "id": "beco", "nome": "Beco atrás da loja", "tipo": "rua", "custo_minutos": 60,
      "posicao_mapa": [0.3, 0.6] },
    { "id": "hospital", "nome": "Hospital Gaylord", "tipo": "rua", "custo_minutos": 45,
      "posicao_mapa": [0.7, 0.2] }
  ],
  "pistas": [
    {
      "id": "pista_1",
      "descricao": "Pegadas de sapato tamanho 42 no beco.",
      "local": "beco",
      "posicao": [-4, 0.15, 3],
      "laboratorio": { "tempo_horas": 6, "conclusao": "Sola de borracha de modelo de trilha, comum em sapatos de trabalho." }
    },
    {
      "id": "pista_2",
      "descricao": "Registro de câmera de segurança mostrando um carro parado no beco.",
      "local": "hospital",
      "posicao": [3, 0.15, -2]
    },
    {
      "id": "pista_3",
      "descricao": "Cofre com marcas de ferramenta por dentro.",
      "local": "beco",
      "posicao": [0, 0.15, 5]
    }
  ],
  "suspeitos": [
    {
      "id": "suspeito_1",
      "nome": "Nome exibido",
      "tipo": "suspeito",
      "personagem_id": null,
      "motivo": "Por que é suspeito.",
      "posicao": [6, 1, 4],
      "rotina": [
        { "dia": 1, "de_hora": 8, "ate_hora": 12, "local": "delegacia" },
        { "dia": 2, "de_hora": 8, "ate_hora": 12, "local": "hospital" }
      ],
      "atitude": "nervoso",
      "limiar_pressao": 3,
      "alibi": {
        "texto": "Estava em casa, sozinho.",
        "falso": true,
        "exposto_por": ["pista_2"]
      },
      "segredos": [
        {
          "id": "segredo_1",
          "descricao": "Esteve no beco na noite do crime.",
          "revelado_com_pressao": true,
          "revelado_por_provas": ["pista_1"],
          "revela_pista": "pista_1"
        }
      ],
      "interrogatorio": [
        {
          "id": "perg_1",
          "pergunta": "Onde você estava na noite do crime?",
          "resposta": "Em casa, sozinho.",
          "pressao": 0,
          "revela_pista": null
        },
        {
          "id": "perg_2",
          "pergunta": "Você esteve no beco?",
          "resposta": "Não.",
          "pressao": 1,
          "resposta_com_prova": { "pista_1": "Tá bom... passei lá. Meus sapatos marcaram o chão." },
          "revela_pista": null
        }
      ]
    }
  ],
  "testemunhas": [
    {
      "id": "testemunha_1",
      "tipo": "testemunha",
      "nome": "Vizinha da vítima",
      "motivo": "Ouviu uma discussão.",
      "posicao": [-6, 1, -4],
      "rotina": [{ "dia": 1, "de_hora": 18, "ate_hora": 23, "local": "beco" }],
      "intimavel": true,
      "interrogatorio": [
        { "id": "perg_1", "pergunta": "Viu alguém?", "resposta": "Um homem de jaqueta vermelha.", "pressao": 0, "revela_pista": null }
      ]
    }
  ],
  "reviravoltas": [
    { "hora": 26, "descricao": "Plantão: a perícia do cofre indica abertura por dentro.", "revela_pista": "pista_3" }
  ],
  "solucao": {
    "culpado": "suspeito_1",
    "pistas_necessarias": ["pista_1", "pista_2"],
    "motivo_correto": "Explicação do crime, mostrada no resultado."
  }
}
```

Este exemplo é parcial, para mostrar a forma dos campos. Um caso real precisa de pelo menos 5 suspeitos, 2 testemunhas e o culpado existente na lista. A validação (`tools/validar_dados.gd`) confere as referências, então o exemplo acima é consistente com ela.

### Regras v2

- `locais`: deve incluir sempre `delegacia` (tipo `delegacia`). Demais são de `tipo: rua` e exigem `custo_minutos` e `posicao_mapa` (valores entre 0 e 1).
- `pistas[].local`: ID de um local. `pistas[].laboratorio` é opcional.
- `suspeitos[].rotina`: lista de janelas de horário (`dia` 1 a 3, `de_hora` e `ate_hora` entre 0 e 24). Fora delas, o suspeito não é encontrado na rua.
- `atitude`: `calmo`, `nervoso`, `arrogante` ou `agressivo`.
- `limiar_pressao`: inteiro entre 1 e 5.
- `alibi.falso`: se `true`, `exposto_por` deve ter ao menos uma pista.
- `interrogatorio[].pressao`: 0 (neutra), 1 (agressiva) ou -1 (empática). `resposta_com_prova` é opcional: chave é o ID de uma pista, valor é a resposta quando o jogador apresenta essa prova.
- `segredos[].revelado_por_provas`: ao apresentar essas provas com pressão suficiente, o segredo é revelado.
- `testemunhas`: `intimavel: true` significa que aparece na delegacia após intimação; caso contrário, só é encontrada na rua pela rotina.
- `reviravoltas`: `hora` é absoluta, de 0 a 48 (0 = dia 1, 08:00).
- `solucao.pistas_necessarias`: ao menos 2.
- `solucao.motivo_correto`: texto para o resultado.

## 7. Divisão de módulos (código)

| Módulo | Arquivos | Responsabilidade |
|---|---|---|
| Relógio | `scripts/core/game_clock.gd` (autoload `GameClock`) | Hora atual, avanço de tempo, prazo de 48h, reviravoltas |
| Estado do caso | `scripts/core/case_state.gd` | Pistas no inventário, provas, laboratório pendente, testemunhas intimadas, segredos revelados |
| Mapa e locais | `scripts/investigation/map_panel.gd`, `scripts/investigation/location_view.gd` | Mapa com locais, viagem, visão 3D do local |
| Interrogatório | `scripts/investigation/interrogation_panel.gd` | Painel de perguntas, pressão e confronto com provas |
| Cérebro do suspeito | `scripts/ai/suspect_brain.gd` | Regras de atitude, pressão, alibi, segredos e respostas |
| Gerador | `tools/gerador_casos/gerar_caso.py` | Chama a API, grava rascunho, roda a validação |

## 8. Ordem de implementação

1. Relógio, estado do caso e mapa com viagem (base de tudo).
2. Cérebro do suspeito e painel de interrogatório com pressão e confronto.
3. Laboratório, intimação de testemunhas e rotinas.
4. Reviravoltas.
5. Gerador de casos com IA.
6. Reescrita dos casos 1 a 3 no formato v2 e um caso novo, com pelo menos 5 suspeitos e 2 testemunhas.

## 9. Pontos em aberto

- **Uso e direitos:** o jogo é pessoal e não será vendido. Os nomes de franquia (Chicago PD, Chicago Fire, Chicago Med, Law & Order: SVU) e personagens são de propriedade da NBC/Universal e da Dick Wolf Productions. Para publicar fora do uso pessoal, seria preciso trocar nomes e personagens.
- **Chave de API:** o gerador precisa de `ANTHROPIC_API_KEY`. Você precisará criar uma chave na conta da Anthropic e defini-la no terminal.
- **Exportação para web:** continua no plano, depois da v2.

## 10. Mandados, consultas e localização (extensão do formato v2)

Opcional: um caso sem essas listas continua válido. Validado por `tools/validar_dados.gd`.

Fluxo do jogador (só na delegacia):
1. **Pedir mandado ao juiz** (`mandatos`): o juiz concede se o jogador já tem pelo menos `pistas_minimas` pistas da `justificativa`. Senão, nega com `motivo_negativa`. Gasta `custo_minutos` em ambos os casos. Ao conceder, libera as pistas de `revela_pistas`.
2. **Consultar sistema** (`consultas`): a sala de dados (tecnologia) só roda a consulta se o mandado de `requer_mandato` foi concedido. Cada consulta gasta `custo_minutos` e mostra `resultado`.
3. Efeitos da consulta: `revela_local` faz o local oculto aparecer no mapa. `localizacao` faz a pessoa aparecer no local, com a janela até `ate_hora`. `revela_pistas` libera pistas.

```json
"mandatos": [
  {
    "id": "mandato_harker", "tipo": "registros", "alvo": "suspeito_2", "custo_minutos": 60,
    "justificativa": ["pista_1", "pista_4"], "pistas_minimas": 1,
    "motivo_negativa": "Texto do juiz quando não há indícios.",
    "concedido_texto": "Texto do juiz quando concede.",
    "revela_pistas": []
  }
],
"consultas": [
  {
    "id": "consulta_harker_agora", "tipo": "agora", "alvo": "suspeito_2",
    "requer_mandato": "mandato_harker", "custo_minutos": 30,
    "revela_local": "predio_gerente",
    "localizacao": { "local": "predio_gerente", "ate_hora": 26 },
    "resultado": "Texto da sala de dados."
  }
]
```

Regras:
- `mandatos[].tipo`: `busca` (busca e apreensão) ou `registros` (telefone e dados). Só muda o texto, não a regra.
- `consultas[].tipo`: `endereco`, `telefone`, `historico` (antenas por onde o celular passou) ou `agora` (celular ativo neste momento).
- `locais[].oculto: true`: o local só aparece no mapa depois de uma consulta com `revela_local`. Todo local oculto precisa ser revelado por alguma consulta.
- `pistas[].oculta: true`: a pista só aparece no local depois de liberada por `revela_pistas` de um mandato ou consulta. Toda pista oculta precisa ser liberada por algum deles.
- `localizacao.ate_hora`: hora absoluta, de 0 a 48 (0 = dia 1, 08:00), como em `reviravoltas`.
- Consultas e mandatos não se repetem. Cada um gasta tempo mesmo quando dá errado.

## 11. Ambientes 3D (cena de cada local)

Cada local pode ter o campo `ambiente`:
- `rua` (padrão para locais de tipo `rua`): cidade com os blocos de `PREDIOS`.
- `delegacia` (padrão para `tipo: delegacia`), `hospital`, `apartamento`, `bar`, `loja`, `galpao`: interior descrito em `data/ambientes/<id>.json`.

O JSON de ambiente tem `chao` (largura, profundidade, cor), `parede` (altura, espessura, cor), `entrada` (`[x, z]`, onde o detetive começa) e `moveis`. Cada móvel tem `modelo` (GLB em `assets/models/`), `centro` (`[x, z]`), `tamanho` (`[largura, altura, profundidade]` do modelo sem girar), `rotacao` (0, 90, 180 ou 270 graus) e `altura_base` (opcional, para quadros e itens de parede).

Regras: o modelo é reduzido sem deformar até caber em `tamanho`. A colisão do detetive usa o retângulo de `tamanho` (girado se `rotacao` for 90 ou 270). Paredes e móveis são obstáculos. O validador confere o id do ambiente e se os modelos existem.

