---
name: criar-suspeito
description: "Adiciona um suspeito a um caso existente em data/cases/ seguindo docs/CONTRATOS.md, com posição, interrogatórios e pistas reveladas válidas. Use quando o usuário pedir um novo suspeito ou testemunha para um caso."
---

# Criar suspeito

Fonte do formato: `docs/CONTRATOS.md` (seção "Formato: caso", bloco `suspeitos`). Não altere o contrato.

## Perguntas ao usuário

1. Em qual caso (`caso_00X`)?
2. Nome exibido do suspeito.
3. Motivo: por que ele é suspeito (uma frase, exibida ao investigar).
4. É um personagem existente (`personagem_id`) ou genérico (`null`)? Se existir, o ID precisa estar em `data/characters/`.
5. Ele é o culpado? Se for, as pistas que o incriminam precisam estar em `solucao.pistas_necessarias`.
6. Perguntas e respostas do interrogatório (mínimo 2). Diga qual pergunta libera qual pista, se houver.

## Regras

- `id` do suspeito: `suspeito_N`, único dentro do caso (veja os IDs já existentes antes de escolher).
- `posicao`: `[x, 1.0, z]`. `y` de pessoa é sempre `1.0`. `x` e `z` entre -8 e 8, sem colidir com outro suspeito ou pista.
- `interrogatorio`: lista com pelo menos 2 itens, cada um com `pergunta`, `resposta` e `revela_pista`.
- `revela_pista`: `null` ou o ID de uma pista que existe **no mesmo caso**.
- Se o suspeito for o culpado, não esqueça de atualizar `solucao.culpado`.
- Edite o JSON do caso com cuidado para não quebrar vírgulas ou colchetes.

## Passos

1. Leia o caso em `data/cases/<caso>.json` e veja IDs de suspeitos, pistas e posições já usados.
2. Adicione o objeto em `suspeitos`.
3. Rode a validação:

```
godot --headless --path /Users/andrehaas/Projetos/ChicagoPD -s res://tools/validar_dados.gd
```

4. Corrija até sair `OK`.
