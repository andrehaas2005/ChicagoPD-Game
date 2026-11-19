#!/usr/bin/env python3
"""
Gerador de casos do ChicagoPD (formato v2, docs/DESIGN_V2.md, seções 5 e 6).

O que faz:
  1. Monta um prompt com as regras do formato v2, os personagens de data/characters/
     e o tema pedido.
  2. Chama a API de Messages da Anthropic e pede JSON puro.
  3. Grava o resultado em data/cases/rascunho/<id>.json.
  4. Roda tools/validar_dados.gd (godot --headless) sobre o rascunho.
     Se passar, move para data/cases/<id>.json. Se falhar, o rascunho fica e os erros aparecem.

Como usar (a partir da raiz do projeto):

  export ANTHROPIC_API_KEY="sua-chave"        # só no terminal, nunca no projeto
  python3 tools/gerador_casos/gerar_caso.py \\
      --tema "crime em Wicker Park envolvendo uma loja de penhores" \\
      --franquia "Chicago Med" \\
      --suspeitos 5 --testemunhas 2 \\
      --id caso_004

Opções:
  --tema        texto do tema (obrigatório)
  --franquia    crossover: "Chicago Med", "Chicago Fire", "Law & Order: SVU" ou "nenhuma".
                "Chicago PD" também aceita e gera caso sem crossover (crossover = null).
  --suspeitos   número de suspeitos, incluindo o culpado (padrão 5)
  --testemunhas número de testemunhas (padrão 2)
  --id          caso_NNN, com três dígitos (obrigatório). A ordem da fase é o número do id.
  --modelo      modelo da API (padrão claude-sonnet-5-5). Ex.: --modelo claude-opus-5-5
  --dry-run     mostra o prompt e sai, sem chamar a API e sem precisar da chave
  --godot       caminho do executável do Godot (padrão: o que estiver no PATH)

Saídas:
  0  caso gerado, validado e movido para data/cases/
  1  erro de uso, de API ou de JSON (se o JSON for inválido, o texto bruto vai para
     tools/gerador_casos/saida_erro.txt; nenhum caso é gravado)
  2  caso gerado, mas reprovado na validação: fica em data/cases/rascunho/ para correção

Segurança: a chave é lida só de ANTHROPIC_API_KEY, nunca é gravada nem impressa.
Não usa bibliotecas externas (apenas a biblioteca padrão do Python 3.9+).
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request

API_URL = "https://api.anthropic.com/v1/messages"
API_VERSAO = "2023-06-01"
MODELO_PADRAO = "claude-sonnet-5-5"
MAX_TOKENS = 8000
TIMEOUT_API = 300

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIR_PERSONAGENS = os.path.join(RAIZ, "data", "characters")
DIR_CASOS = os.path.join(RAIZ, "data", "cases")
DIR_RASCUNHOS = os.path.join(DIR_CASOS, "rascunho")
ARQUIVO_ERRO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "saida_erro.txt")
VALIDADOR = "res://tools/validar_dados.gd"
GODOT_PADRAO = "/opt/homebrew/bin/godot"

FRANQUIAS_CROSSOVER = ["Chicago Med", "Chicago Fire", "Law & Order: SVU"]
FRANQUIAS_ACEITAS = FRANQUIAS_CROSSOVER + ["Chicago PD", "nenhuma"]

EXEMPLO_V2 = {
    "id": "caso_004",
    "titulo": "Caso 004: Penhor na Division Street",
    "resumo": "Um corretor de penhores é encontrado morto nos fundos da loja.",
    "ordem": 4,
    "crossover": "Chicago Med",
    "duracao_horas": 48,
    "personagens": ["reyes"],
    "locais": [
        {"id": "delegacia", "nome": "Delegacia do 21º Distrito", "tipo": "delegacia"},
        {"id": "loja", "nome": "Penhor da Division Street", "tipo": "rua",
         "custo_minutos": 60, "posicao_mapa": [0.3, 0.6]},
        {"id": "hospital", "nome": "Hospital Gaylord", "tipo": "rua",
         "custo_minutos": 45, "posicao_mapa": [0.7, 0.2]},
    ],
    "pistas": [
        {"id": "pista_1", "descricao": "Recibo de penhor com digital parcial.",
         "local": "loja", "posicao": [-4, 0.15, 3],
         "laboratorio": {"tempo_horas": 6,
                         "conclusao": "A digital confere com a ficha de suspeito_1."}},
        {"id": "pista_2", "descricao": "Curativo ensanguentado no lixo dos fundos.",
         "local": "loja", "posicao": [3, 0.15, -2]},
    ],
    "suspeitos": [
        {
            "id": "suspeito_1", "nome": "Tomás Vidal", "tipo": "suspeito",
            "personagem_id": None,
            "motivo": "Devia dinheiro ao penhor e discutiu com a vítima.",
            "posicao": [6, 1, 4],
            "rotina": [
                {"dia": 1, "de_hora": 8, "ate_hora": 12, "local": "delegacia"},
                {"dia": 2, "de_hora": 8, "ate_hora": 12, "local": "hospital"},
            ],
            "atitude": "nervoso",
            "limiar_pressao": 3,
            "alibi": {"texto": "Estava em casa, sozinho.", "falso": True,
                      "exposto_por": ["pista_1"]},
            "segredos": [
                {"id": "segredo_1", "descricao": "Esteve na loja na noite do crime.",
                 "revelado_com_pressao": True, "revelado_por_provas": ["pista_1"],
                 "revela_pista": None},
            ],
            "interrogatorio": [
                {"id": "perg_1", "pergunta": "Onde você estava na noite do crime?",
                 "resposta": "Em casa, sozinho.", "pressao": 0, "revela_pista": None},
                {"id": "perg_2", "pergunta": "Você esteve na loja?",
                 "resposta": "Não.", "pressao": 1,
                 "resposta_com_prova": {"pista_1": "Tá bom, passei lá. Eu devia dinheiro."},
                 "revela_pista": None},
            ],
        },
        {
            "id": "suspeito_2", "nome": "Carla Mendes", "tipo": "suspeito",
            "personagem_id": None,
            "motivo": "Sócia do penhor, com acesso ao cofre.",
            "posicao": [-5, 1, -2],
            "rotina": [{"dia": 1, "de_hora": 18, "ate_hora": 23, "local": "loja"}],
            "atitude": "calmo",
            "limiar_pressao": 2,
            "alibi": {"texto": "Jantava com a família.", "falso": False, "exposto_por": []},
            "segredos": [],
            "interrogatorio": [
                {"id": "perg_1", "pergunta": "Onde estava à noite?",
                 "resposta": "Jantando com a família.", "pressao": 0, "revela_pista": None},
                {"id": "perg_2", "pergunta": "Quem tinha a chave do cofre?",
                 "resposta": "Eu e a vítima.", "pressao": -1, "revela_pista": None},
            ],
        },
    ],
    "testemunhas": [
        {
            "id": "testemunha_1", "tipo": "testemunha", "nome": "Vizinho do andar de cima",
            "motivo": "Ouviu uma discussão por volta da meia-noite.",
            "posicao": [-6, 1, -4],
            "rotina": [{"dia": 1, "de_hora": 18, "ate_hora": 23, "local": "loja"}],
            "intimavel": True,
            "interrogatorio": [
                {"id": "perg_1", "pergunta": "Viu alguém?",
                 "resposta": "Um homem de jaqueta vermelha.", "pressao": 0, "revela_pista": None},
                {"id": "perg_2", "pergunta": "Ouviu algo?",
                 "resposta": "Uma briga e um barulho de vidro.", "pressao": 0, "revela_pista": None},
            ],
        },
    ],
    "reviravoltas": [
        {"hora": 26, "descricao": "Plantão: o laboratório confirma a digital.", "revela_pista": None},
    ],
    "solucao": {
        "culpado": "suspeito_1",
        "pistas_necessarias": ["pista_1", "pista_2"],
        "motivo_correto": "Tomás brigou com a vítima por causa da dívida e a matou nos fundos da loja.",
    },
}

REGRAS_V2 = """\
FORMATO DO CASO (v2). Responda com um único objeto JSON.

Campos de nível superior, todos obrigatórios:
- id: "caso_NNN" (igual ao pedido), titulo, resumo (texto curto de abertura).
- ordem: inteiro, igual ao número do id (ex.: caso_004 -> 4).
- crossover: null ou o nome da franquia convidada (exatamente como pedido).
- duracao_horas: 48.
- personagens: lista de IDs da lista de personagens disponíveis (pode ser vazia).
- locais: lista. Deve ter EXATAMENTE um local com id "delegacia" e tipo "delegacia".
  Os demais têm tipo "rua", custo_minutos (número entre 30 e 120) e posicao_mapa [x, y]
  com valores entre 0 e 1. Ao menos 2 locais de rua.
- pistas: 2 a 4 itens. Cada um: id ("pista_N"), descricao, local (ID de locais),
  posicao [x, 0.15, z]. Opcional: laboratorio {tempo_horas (>= 0), conclusao (texto)}.
- suspeitos: exatamente o número pedido. Cada um:
  id ("suspeito_N"), nome, tipo "suspeito", personagem_id (null ou ID da lista de personagens),
  motivo, posicao [x, 1, z], rotina, atitude, limiar_pressao, alibi, segredos, interrogatorio.
  * rotina: lista de janelas {dia (1, 2 ou 3), de_hora, ate_hora (0 a 24, de_hora < ate_hora),
    local (ID de locais)}. Fora delas o suspeito não é encontrado na rua.
  * atitude: exatamente "calmo", "nervoso", "arrogante" ou "agressivo".
  * limiar_pressao: inteiro de 1 a 5.
  * alibi: {texto, falso (true/false), exposto_por (lista de IDs de pistas)}.
    Se falso for true, exposto_por tem ao menos uma pista.
  * segredos: lista de {id ("segredo_N"), descricao, revelado_com_pressao (true/false),
    revelado_por_provas (lista de IDs de pistas), revela_pista (ID de pista ou null)}.
  * interrogatorio: 2 a 4 perguntas {id ("perg_N", únicos dentro da pessoa), pergunta,
    resposta, pressao (exatamente -1, 0 ou 1), revela_pista (ID de pista ou null),
    resposta_com_prova (opcional: objeto cuja chave é ID de pista e o valor é a resposta
    quando o jogador apresenta essa prova)}.
- testemunhas: exatamente o número pedido (pode ser 0). Cada uma:
  id ("testemunha_N"), tipo "testemunha", nome, motivo, posicao [x, 1, z], rotina, intimavel
  (true/false; pelo menos uma deve ser true), interrogatorio (mesmas regras).
  Testemunhas usam IDs diferentes dos suspeitos (ids devem ser únicos no caso inteiro).
- reviravoltas: lista (pode ser vazia). Cada uma: {hora (número de 0 a 48), descricao,
  revela_pista (ID de pista ou null)}.
- solucao: {culpado (ID de um suspeito), pistas_necessarias (2 ou mais IDs de pistas),
  motivo_correto (texto explicando o crime)}.

REGRAS DE COERÊNCIA (o validador verifica, e o jogo depende delas):
- Todo ID citado (local, pista, suspeito, testemunha, personagem) deve existir no próprio caso
  ou na lista de personagens.
- O culpado precisa ter alibi falso, exposto por pelo menos uma pista das pistas_necessarias.
- As pistas_necessarias precisam comprovar o crime e ser encontráveis: cada pista está em um
  local que o jogador consegue visitar, e pode ser pega por rotina de alguma pessoa.
- Pelo menos um segredo do culpado é revelado por provas.
- Posições x e z entre -8 e 8. Pistas e pessoas não podem ocupar a mesma posição.
- Use texto em português do Brasil, sem acento em IDs e nomes de arquivo.
- Não copie personagens reais de elenco. Personagens são originais, inspirados nas franquias.
"""

INSTRUCAO_SAIDA = """\
SAÍDA: responda SOMENTE com o objeto JSON válido. Sem texto antes ou depois, sem
explicações, sem cercas de markdown (```). A primeira letra da resposta deve ser "{"
e a última deve ser "}".
"""

SYSTEM = (
    "Você é roteirista de um jogo de investigação policial em Chicago (ChicagoPD). "
    "Escreve casos em português do Brasil, seguindo estritamente a especificação "
    "fornecida, e responde apenas com JSON válido."
)


def ler_personagens():
    """Lê data/characters/*.json. Retorna lista de dicts ordenada por id."""
    personagens = []
    if not os.path.isdir(DIR_PERSONAGENS):
        return personagens
    for nome in sorted(os.listdir(DIR_PERSONAGENS)):
        if not nome.endswith(".json"):
            continue
        with open(os.path.join(DIR_PERSONAGENS, nome), encoding="utf-8") as f:
            dados = json.load(f)
        personagens.append(dados)
    return personagens


def formatar_personagens(personagens):
    linhas = []
    for p in personagens:
        papel = "jogável" if p.get("jogavel") else "crossover, não jogável"
        linhas.append('- "%s": %s (%s, %s)' % (p["id"], p["nome"], p["franquia"], papel))
    return "\n".join(linhas)


def montar_prompt(tema, franquia, suspeitos, testemunhas, caso_id, personagens):
    crossover = None if franquia in ("nenhuma", "Chicago PD") else franquia
    ordem = int(caso_id.split("_")[1])
    exemplo = json.dumps(EXEMPLO_V2, ensure_ascii=False, indent=2)
    return (
        "Crie UM caso de investigação com as especificações abaixo.\n\n"
        "PEDIDO\n"
        "- Tema: %s\n"
        "- id: %s\n"
        "- ordem: %d\n"
        "- crossover (use exatamente este valor): %s\n"
        "- suspeitos: %d (incluindo o culpado)\n"
        "- testemunhas: %d\n\n"
        "PERSONAGENS DISPONÍVEIS (IDs válidos para \"personagens\" e \"personagem_id\"):\n"
        "%s\n"
        "Personagens de crossover não jogáveis podem aparecer como suspeitos ou testemunhas. "
        "Não invente IDs fora desta lista.\n\n"
        "%s\n"
        "EXEMPLO DE CASO VÁLIDO (só para mostrar a estrutura; o caso novo deve ser outro, "
        "com tema e personagens próprios):\n%s\n\n"
        "%s"
    ) % (
        tema,
        caso_id,
        ordem,
        "null" if crossover is None else '"%s"' % crossover,
        suspeitos,
        testemunhas,
        formatar_personagens(personagens) or "(nenhum personagem cadastrado)",
        REGRAS_V2,
        exemplo,
        INSTRUCAO_SAIDA,
    )


def chamar_api(chave, modelo, prompt):
    corpo = {
        "model": modelo,
        "max_tokens": MAX_TOKENS,
        "system": SYSTEM,
        "messages": [{"role": "user", "content": prompt}],
    }
    dados = json.dumps(corpo).encode("utf-8")
    req = urllib.request.Request(
        API_URL,
        data=dados,
        method="POST",
        headers={
            "x-api-key": chave,
            "anthropic-version": API_VERSAO,
            "content-type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_API) as resposta:
            resultado = json.loads(resposta.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detalhe = e.read().decode("utf-8", errors="replace")[:500]
        raise RuntimeError("API respondeu HTTP %d: %s" % (e.code, detalhe))
    except urllib.error.URLError as e:
        raise RuntimeError("Falha de rede ao chamar a API: %s" % e.reason)

    if resultado.get("stop_reason") == "max_tokens":
        print("AVISO: a resposta foi cortada pelo limite de tokens (max_tokens=%d)." % MAX_TOKENS,
              file=sys.stderr)
    partes = [b.get("text", "") for b in resultado.get("content", []) if b.get("type") == "text"]
    return "".join(partes)


def achar_godot(informado):
    if informado:
        return informado
    return shutil.which("godot") or (GODOT_PADRAO if os.path.exists(GODOT_PADRAO) else None)


def validar_rascunho(godot, caso_id):
    """Roda o validador só sobre o rascunho. Retorna (ok, saida)."""
    comando = [
        godot, "--headless", "--path", RAIZ,
        "-s", VALIDADOR, "--",
        "--rascunhos", "--arquivo=%s.json" % caso_id,
    ]
    proc = subprocess.run(comando, capture_output=True, text=True, timeout=300)
    linhas = [l for l in (proc.stdout + proc.stderr).splitlines()
              if l.startswith("ERRO") or l.startswith("OK") or "Validação falhou" in l]
    return proc.returncode == 0, "\n".join(linhas)


def parser():
    p = argparse.ArgumentParser(
        description="Gera um caso do ChicagoPD (formato v2) com a API do Claude e valida.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Exemplo:\n  python3 tools/gerador_casos/gerar_caso.py --tema \"...\" --franquia \"Chicago Med\" --id caso_004",
    )
    p.add_argument("--tema", required=True, help="tema do caso, em texto livre")
    p.add_argument("--franquia", choices=FRANQUIAS_ACEITAS, default="nenhuma",
                   help="franquia do crossover (padrão: nenhuma)")
    p.add_argument("--suspeitos", type=int, default=5, help="número de suspeitos (padrão 5)")
    p.add_argument("--testemunhas", type=int, default=2, help="número de testemunhas (padrão 2)")
    p.add_argument("--id", dest="caso_id", required=True, metavar="caso_NNN",
                   help="id do caso, ex.: caso_004")
    p.add_argument("--modelo", default=MODELO_PADRAO, help="modelo da API (padrão %s)" % MODELO_PADRAO)
    p.add_argument("--dry-run", action="store_true", help="mostra o prompt e sai, sem chamar a API")
    p.add_argument("--godot", default=None, help="caminho do executável do Godot")
    return p


def main(argv=None):
    args = parser().parse_args(argv)

    if not re.match(r"^caso_[0-9]{3}$", args.caso_id):
        print("ERRO: --id deve ter o formato caso_NNN (ex.: caso_004).", file=sys.stderr)
        return 1
    if args.suspeitos < 1 or args.testemunhas < 0:
        print("ERRO: --suspeitos deve ser >= 1 e --testemunhas >= 0.", file=sys.stderr)
        return 1

    destino = os.path.join(DIR_CASOS, args.caso_id + ".json")
    rascunho = os.path.join(DIR_RASCUNHOS, args.caso_id + ".json")
    if os.path.exists(destino):
        print("ERRO: %s já existe. Escolha outro --id." % os.path.relpath(destino, RAIZ), file=sys.stderr)
        return 1

    personagens = ler_personagens()
    prompt = montar_prompt(args.tema, args.franquia, args.suspeitos, args.testemunhas,
                           args.caso_id, personagens)

    if args.dry_run:
        print(prompt)
        print("\n--- dry-run: nada foi enviado à API e nada foi gravado. Modelo: %s" % args.modelo,
              file=sys.stderr)
        return 0

    chave = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if not chave:
        print("ERRO: defina a variável de ambiente ANTHROPIC_API_KEY antes de rodar.\n"
              "  export ANTHROPIC_API_KEY=\"sua-chave\"", file=sys.stderr)
        return 1

    godot = achar_godot(args.godot)
    if godot is None:
        print("ERRO: Godot não encontrado. Informe --godot /caminho/para/godot.", file=sys.stderr)
        return 1

    print("Chamando a API (%s)... isso pode levar alguns minutos." % args.modelo)
    try:
        texto = chamar_api(chave, args.modelo, prompt)
    except RuntimeError as e:
        print("ERRO: %s" % e, file=sys.stderr)
        return 1

    try:
        caso = json.loads(texto.strip())
        if not isinstance(caso, dict):
            raise ValueError("a resposta não é um objeto JSON")
    except ValueError as e:
        with open(ARQUIVO_ERRO, "w", encoding="utf-8") as f:
            f.write(texto)
        print("ERRO: a resposta não é JSON válido (%s)." % e, file=sys.stderr)
        print("Texto bruto salvo em %s. Nenhum caso foi gravado." % ARQUIVO_ERRO, file=sys.stderr)
        return 1

    caso["id"] = args.caso_id
    os.makedirs(DIR_RASCUNHOS, exist_ok=True)
    with open(rascunho, "w", encoding="utf-8") as f:
        json.dump(caso, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("Rascunho gravado em %s" % os.path.relpath(rascunho, RAIZ))

    print("Validando...")
    ok, saida = validar_rascunho(godot, args.caso_id)
    if saida:
        print(saida)
    if not ok:
        print("Caso reprovado na validação. Rascunho mantido em %s para correção."
              % os.path.relpath(rascunho, RAIZ))
        return 2

    os.replace(rascunho, destino)
    print("OK: caso movido para %s" % os.path.relpath(destino, RAIZ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
