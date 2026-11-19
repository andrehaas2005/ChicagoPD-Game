---
name: criar-caso
description: "Cria um caso JSON completo em data/cases/ (ordem, crossover, personagens, pistas, suspeitos e solução) seguindo docs/CONTRATOS.md. Use quando o usuário pedir um novo caso ou fase do ChicagoPD."
---

# Criar caso

Fonte do formato: `docs/DESIGN_V2.md` (seção 6, formato v2, que vale para casos novos). `docs/CONTRATOS.md` continua valendo para personagens e para o formato v1 dos casos 1 a 3. Não altere os contratos.

## Caminho preferido: gerador com IA

Use o gerador `tools/gerador_casos/gerar_caso.py`. Ele monta o prompt com as regras v2 e os personagens de `data/characters/`, chama a API, grava em `data/cases/rascunho/`, roda a validação e move o caso para `data/cases/` só se passar.

Pergunte ao usuário o tema, a franquia de crossover (`Chicago Med`, `Chicago Fire`, `Law & Order: SVU` ou `nenhuma`), o número de suspeitos e testemunhas, e o id `caso_NNN` (o próximo número livre em `data/cases/`). Depois rode, a partir da raiz do projeto:

```
python3 tools/gerador_casos/gerar_caso.py --tema "crime em Wicker Park envolvendo uma loja de penhores" --franquia "Chicago Med" --suspeitos 5 --testemunhas 2 --id caso_004
```

Requisitos: variável `ANTHROPIC_API_KEY` no terminal (nunca no projeto). Use `--dry-run` para ver o prompt sem gastar chamadas. Use `--modelo claude-opus-5-5` se quiser um modelo mais forte.

Saídas: exit 0 significa caso pronto em `data/cases/`. Exit 2 significa que a validação reprovou: o rascunho fica em `data/cases/rascunho/` e os erros aparecem no terminal. Nesse caso, corrija o rascunho à mão (ou gere de novo com outro `--id`) e rode a validação com `--rascunhos --arquivo=caso_NNN.json`. Se a resposta não for JSON, o texto bruto vai para `tools/gerador_casos/saida_erro.txt`.

## Caminho manual (alternativa)

Se o gerador não puder ser usado (sem chave de API ou sem rede), escreva o caso à mão seguindo o formato v2 de `docs/DESIGN_V2.md`, seção 6, com as regras dessa seção.

## Roteiro de perguntas ao usuário

1. Título e resumo curto (o resumo aparece na seleção de caso).
2. Local (ex.: "Halsted Street, Chicago").
3. Número da fase (`ordem`): use o próximo número livre em `data/cases/`.
4. Crossover: `null` ou a franquia convidada (`Chicago Med`, `Chicago Fire`, `Law & Order: SVU`).
5. Personagens que aparecem no caso (IDs de `data/characters/`), se houver.
6. Culpado: quem é, qual o motivo, e qual a cadeia de provas.
7. Pistas (2 a 3): descrição e posição no chão.
8. Suspeitos (3 no total, incluindo o culpado): nome, motivo, posição, interrogatórios.

## Regras do formato v1 (referência para casos antigos; o caminho manual novo usa v2)

- `id`: `caso_NNN`, igual ao nome do arquivo `data/cases/caso_NNN.json`.
- `ordem`: número inteiro da fase.
- `pistas`: 2 a 3, com `posicao` `[x, 0.15, z]`. `x` e `z` entre -8 e 8.
- `suspeitos`: `posicao` `[x, 1.0, z]`, `x` e `z` entre -8 e 8, sem colidir com pistas.
- Cada suspeito tem `interrogatorio` com pelo menos 2 perguntas. `revela_pista` é `null` ou ID de pista do próprio caso.
- `solucao.culpado`: ID de um suspeito do caso.
- `solucao.pistas_necessarias`: pelo menos uma pista que comprove o caso. Não deixe o culpado sem prova física ou testemunhal no caso.
- `personagens` e `personagem_id`: só IDs que existem em `data/characters/`.

## Passos do caminho manual (formato v1; para v2, siga `docs/DESIGN_V2.md` seção 6)

1. Colete as respostas e monte a história em poucas linhas, com a cadeia de provas.
2. Escreva `data/cases/caso_NNN.json` seguindo o contrato.
3. Checklist final (v1):
   - [ ] `id` igual ao nome do arquivo e `ordem` única
   - [ ] 2 a 3 pistas com `y = 0.15` e `x`/`z` em -8..8
   - [ ] 3 suspeitos com `y = 1.0`, cada um com 2+ interrogatórios
   - [ ] `revela_pista` só aponta para pistas deste caso
   - [ ] `culpado` é um suspeito do caso
   - [ ] `pistas_necessarias` existem e comprovam a solução
   - [ ] `personagens` e `personagem_id` existem em `data/characters/`
4. Rode a validação e corrija até sair `OK`:

```
godot --headless --path /Users/andrehaas/Projetos/ChicagoPD -s res://tools/validar_dados.gd
```
