#!/usr/bin/env python3
"""
Converte um GLB que usa KHR_mesh_quantization para atributos float32 comuns.

Por quê: o Godot 4.7 não importa GLBs que exigem essa extensão (o import fica com valid=false).
Os modelos do 3dassets.dev usam essa extensão. O script só troca o formato dos atributos
(POSITION, NORMAL, TANGENT, TEXCOORD_n, COLOR_n) para float32, sem mudar a geometria,
e remove a extensão do arquivo.

Uso (a partir da raiz do projeto):
  python3 -I tools/glb_sem_quantizacao.py assets/models/arquivo.glb

O arquivo é sobrescrito. Mantenha a cópia original se quiser comparar.
Só usa a biblioteca padrão do Python 3.
"""

import json
import struct
import sys

EXTENSAO = "KHR_mesh_quantization"
TAMANHO_COMPONENTE = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
FORMATO = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
NUM_COMPONENTES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
MAXIMO_NORMALIZADO = {5120: 127.0, 5121: 255.0, 5122: 32767.0, 5123: 65535.0}


def ler_glb(caminho):
    with open(caminho, "rb") as f:
        dados = f.read()
    if dados[0:4] != b"glTF":
        raise ValueError("não é um GLB")
    tamanho_json = struct.unpack("<I", dados[12:16])[0]
    json_bytes = dados[20:20 + tamanho_json]
    inicio_bin = 20 + tamanho_json
    tamanho_bin = struct.unpack("<I", dados[inicio_bin:inicio_bin + 4])[0]
    bin_bytes = dados[inicio_bin + 8:inicio_bin + 8 + tamanho_bin]
    return json.loads(json_bytes), bytearray(bin_bytes)


def ler_valores(gltf, bin_bytes, indice_accessor):
    accessor = gltf["accessors"][indice_accessor]
    view = gltf["bufferViews"][accessor["bufferView"]]
    comp = accessor["componentType"]
    n = NUM_COMPONENTES[accessor["type"]]
    tam = TAMANHO_COMPONENTE[comp]
    passo = view.get("byteStride", n * tam)
    base = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    fmt = "<" + FORMATO[comp] * n
    normalizado = accessor.get("normalized", False)
    valores = []
    for i in range(accessor["count"]):
        bruto = struct.unpack_from(fmt, bin_bytes, base + i * passo)
        if normalizado and comp in MAXIMO_NORMALIZADO:
            maximo = MAXIMO_NORMALIZADO[comp]
            bruto = tuple(max(-1.0, v / maximo) if comp in (5120, 5122) else v / maximo for v in bruto)
        valores.append(bruto)
    return valores, n


def converter(gltf, bin_bytes):
    alvos = set()
    for malha in gltf.get("meshes", []):
        for primitiva in malha.get("primitives", []):
            for nome, indice in primitiva.get("attributes", {}).items():
                if nome.startswith(("POSITION", "NORMAL", "TANGENT", "TEXCOORD", "COLOR")):
                    alvos.add(indice)

    novo_bin = bytearray(bin_bytes)
    for indice in sorted(alvos):
        accessor = gltf["accessors"][indice]
        if accessor["componentType"] == 5126 and not accessor.get("normalized", False):
            continue
        valores, n = ler_valores(gltf, bin_bytes, indice)
        dados = bytearray()
        for valor in valores:
            dados += struct.pack("<" + "f" * n, *[float(v) for v in valor])
        while len(novo_bin) % 4 != 0:
            novo_bin.append(0)
        deslocamento = len(novo_bin)
        novo_bin += dados
        gltf["bufferViews"].append({
            "buffer": 0,
            "byteOffset": deslocamento,
            "byteLength": len(dados),
            "target": 34962,
        })
        accessor["bufferView"] = len(gltf["bufferViews"]) - 1
        accessor["byteOffset"] = 0
        accessor["componentType"] = 5126
        accessor.pop("normalized", None)

    for lista in ("extensionsUsed", "extensionsRequired"):
        if EXTENSAO in gltf.get(lista, []):
            gltf[lista].remove(EXTENSAO)
            if not gltf[lista]:
                del gltf[lista]

    while len(novo_bin) % 4 != 0:
        novo_bin.append(0)
    gltf["buffers"][0]["byteLength"] = len(novo_bin)
    return gltf, novo_bin


def escrever_glb(caminho, gltf, bin_bytes):
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    while len(json_bytes) % 4 != 0:
        json_bytes += b" "
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
    with open(caminho, "wb") as f:
        f.write(b"glTF")
        f.write(struct.pack("<II", 2, total))
        f.write(struct.pack("<I4s", len(json_bytes), b"JSON"))
        f.write(json_bytes)
        f.write(struct.pack("<I4s", len(bin_bytes), b"BIN\x00"))
        f.write(bin_bytes)


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 1
    caminho = sys.argv[1]
    gltf, bin_bytes = ler_glb(caminho)
    usados = gltf.get("extensionsUsed", [])
    if EXTENSAO not in usados:
        print("sem KHR_mesh_quantization, nada a fazer:", caminho)
        return 0
    gltf, novo_bin = converter(gltf, bin_bytes)
    escrever_glb(caminho, gltf, novo_bin)
    print("convertido:", caminho)
    return 0


if __name__ == "__main__":
    sys.exit(main())
