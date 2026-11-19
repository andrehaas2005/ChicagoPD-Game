---
name: criar-personagem
description: "Cria um personagem JSON em data/characters/ seguindo docs/CONTRATOS.md. Use quando o usuário pedir um novo personagem jogável ou de crossover para o ChicagoPD."
---

# Criar personagem

Fonte do formato: `docs/CONTRATOS.md` (seção "Formato: personagem"). Não altere o contrato.

## Perguntas ao usuário

Pergunte, se ainda não souber:
1. Nome completo (ficcional, original; não use dados de atores reais).
2. Franquia: `Chicago PD`, `Chicago Fire`, `Chicago Med`, `Law & Order: SVU` ou `Original`.
3. Cargo curto (ex.: "Detetive", "Médica emergencista").
4. Descrição curta (1 frase, sem falas copiadas).
5. Cor de destaque em hex (`#rrggbb`). Se não souber, sugira uma cor ainda não usada em `data/characters/`.
6. Jogável (`true`, aparece como detetive) ou não (`false`, só suspeito ou testemunha de crossover).

## Regras

- Nome do arquivo: `data/characters/<id>.json`.
- `id`: minúsculo, sem acento, sem espaço (use `_`), e igual ao nome do arquivo sem `.json`.
- `id` único entre todos os personagens.
- Campos obrigatórios: `id`, `nome`, `franquia`, `cargo`, `descricao`, `cor`, `jogavel`.
- Use tabs ou 2 espaços e mantenha JSON válido.

## Passos

1. Confirme as respostas acima.
2. Crie o arquivo com o formato do contrato.
3. Rode a validação:

```
godot --headless --path /Users/andrehaas/Projetos/ChicagoPD -s res://tools/validar_dados.gd
```

4. Se houver erro, corrija o arquivo e rode de novo até sair `OK`.
