# Licenças dos modelos 3D

Ambos os modelos são CC0 1.0 Universal (domínio público, sem atribuição obrigatória), publicados em https://3dassets.dev.

| Arquivo | Origem | Licença |
|---|---|---|
| `pessoa_courier.glb` | https://3dassets.dev/assets/frontier-courier-character (slug `frontier-courier-character`, id 131) | CC0 1.0 |
| `pista_marcador.glb` | https://3dassets.dev/assets/police-station-and-detective-office-evidence-marker-se-779aa2b9 (id 29976) | CC0 1.0 |
| `detetive_navegador.glb` | https://3dassets.dev/assets/tidal-navigator-character (id 257) | CC0 1.0 |

## Observação técnica

Os GLBs do 3dassets.dev usam `KHR_mesh_quantization`, que o Godot 4.7 não importa. `pista_marcador.glb` foi convertido com `tools/glb_sem_quantizacao.py` (atributos passados para float32, geometria inalterada). A licença continua CC0.

## Prédios (série Voxel City Districts, 3dassets.dev, CC0 1.0)

| Arquivo | Origem | Uso |
|---|---|---|
| `predio_garagem.glb` | https://3dassets.dev/assets/voxel-city-districts-garage-house-6fa7e8ae (id 24770) | bloco 0 da cidade |
| `predio_cafe.glb` | https://3dassets.dev/assets/voxel-city-districts-corner-cafe-6d4c7f91 (id 24773) | bloco 1 |
| `predio_oficina.glb` | https://3dassets.dev/assets/voxel-city-districts-workshop-shed-08af1523 (id 24778) | bloco 2 |
| `predio_escritorio.glb` | https://3dassets.dev/assets/voxel-city-districts-office-setback-868949ab (id 24776) | bloco 3 |
| `predio_arcade.glb` | https://3dassets.dev/assets/voxel-city-districts-arcade-market-80e7a9d7 (id 24771) | bloco 4 |

Todos passaram por `tools/glb_sem_quantizacao.py`. Todos CC0 1.0, sem atribuição obrigatória.

## Móveis de interior (3dassets.dev, CC0 1.0)

Usados em `data/ambientes/*.json`. Todos passaram por `tools/glb_sem_quantizacao.py`.

| Arquivo | Origem (id 3dassets) | Ambiente |
|---|---|---|
| `delegacia_mesa.glb` | squad-desk-with-divider (29955) | delegacia |
| `delegacia_cadeira.glb` | office-task-chair (29956) | delegacia |
| `delegacia_cadeira_interro.glb` | floor-fixed-interview-chair (29978) | delegacia |
| `delegacia_arquivo.glb` | evidence-shelving-rack (29973) | delegacia |
| `delegacia_quadro.glb` | evidence-board-with-pinned-photographs (29969) | delegacia |
| `hospital_cama.glb` | adjustable-ward-bed (23588) | hospital |
| `hospital_mesa_cama.glb` | over-bed-table (23590) | hospital |
| `apto_sofa3.glb` | sofa-three-seat (38778) | apartamento |
| `apto_sofa2.glb` | loveseat-small (38783) | apartamento |
| `apto_cama_dia.glb` | day-bed (23592) | apartamento |
| `bar_balcao.glb` | bar-counter-section (33871) | bar |
| `bar_banqueta.glb` | bar-stool (33866) | bar |
| `loja_estante.glb` | shop-shelving-bay-2400 (23870) | loja |
| `loja_caixa.glb` | cash-desk-back-fixture (25317) | loja |
| `loja_balcao_caixa.glb` | counter-till-point (23886) | loja |
| `galpao_palete.glb` | pallet-with-parts-crates (27858) | galpão |
| `galpao_carrinho.glb` | warehouse-shelf-trolley (23960) | galpão |
| `galpao_barris.glb` | pallet-of-casks (38703) | galpão |

## Tribunal (3dassets.dev, pacote City Courthouse and Records Office, CC0 1.0)

| Arquivo | Origem (id 3dassets) |
|---|---|
| `tribunal_juiz_banco.glb` | Judge Bench (30957) |
| `tribunal_caixa_juri.glb` | Jury Box (30964) |
| `tribunal_banco_testemunha.glb` | Witness Stand (30960) |
| `tribunal_galeria_banco.glb` | Public Gallery Bench (30966) |
| `tribunal_mesa_defesa.glb` | Counsel Table (30962) |
| `tribunal_tribuna.glb` | Lectern (30969) |
| `tribunal_cadeira_advogado.glb` | Counsel Chair (30963) |
| `tribunal_tela_provas.glb` | Evidence Presentation Screen (30970) |
| `tribunal_carrinho_provas.glb` | Evidence Trolley (30981) |
| `tribunal_brasao.glb` | Court Crest Plaque (31000) |
| `tribunal_agua.glb` | Water Service Stand (30999) |
