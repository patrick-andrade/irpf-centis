# Distribuição de renda e patrimônio no IRPF

[![Publicar site](https://github.com/patrick-andrade/irpf-centis/actions/workflows/deploy-pages.yml/badge.svg)](https://github.com/patrick-andrade/irpf-centis/actions/workflows/deploy-pages.yml)
[![CI](https://github.com/patrick-andrade/irpf-centis/actions/workflows/ci.yml/badge.svg)](https://github.com/patrick-andrade/irpf-centis/actions/workflows/ci.yml)

Projeto reprodutível para analisar a distribuição dos rendimentos, da tributação e dos bens declarados no Imposto de Renda da Pessoa Física por centis, anos e unidades da Federação.

**Site publicado:** <https://patrick-andrade.github.io/irpf-centis/> — relatórios em HTML/PDF e **painel interativo** que roda no navegador (shinylive/WebAssembly), sem servidor.

> **Universo:** os dados representam declarações válidas do IRPF. Não descrevem diretamente toda a população brasileira. Centis estaduais são posições relativas dentro de cada UF e não equivalem aos mesmos cortes nacionais.

## Estado do projeto

- Série principal de renda: anos-calendário 2017–2024 (conceito central: RB4).
- Série patrimonial de ordenação direta: 2006–2021 (Tabela III nacional).
- Valores reais: preços de 2024 pelo IPCA anual; nominais preservados nos dados curados.
- Indicadores: Gini agrupado (com limites de Gastwirth), Theil T, Atkinson (ε = 0,5 e 1), Wolfson, Esteban–Ray, participações de topo/base, Palma, P90/P50, alíquota efetiva média e decomposição de Theil por UF.
- Produtos: site Quarto (relatório, sumário executivo, apêndice técnico, metodologia, diagnóstico) + painel Shiny/shinylive.
- `run.cmd release` continua bloqueado até a revisão humana registrada em `docs/release-checklist.md`.

O plano original aprovado está em [`docs/plano-v01.md`](docs/plano-v01.md); a auditoria e as mudanças desta rodada estão em [`docs/diagnostico-tecnico.md`](docs/diagnostico-tecnico.md).

## Pré-requisitos

- R 4.6.0.
- Quarto 1.9 ou superior.
- Git Bash no Windows.
- Dependências restauradas com `renv::restore()`.

## Comandos

No Windows:

```text
run.cmd discover
run.cmd download 2024
run.cmd context
run.cmd build
run.cmd check
run.cmd render
run.cmd site
run.cmd app
run.cmd release
```

No Git Bash, substitua `run.cmd` por `./run.sh`.

`context` baixa os deflatores do IPCA e a malha estadual do IBGE. `site` renderiza o site Quarto e exporta o painel shinylive em `output/site`. `release` monta um pacote local auditável; não publica nem envia arquivos a serviços externos.

## Fluxo dos dados

1. `discover` lê as páginas oficiais e produz `data/metadata/sources-discovered.csv`.
2. `download` baixa arquivos imutáveis, registra tamanho e SHA-256 em `data/metadata/sources-manifest.csv`.
3. `context` atualiza `data/external/` (IPCA anual e malha das UFs).
4. `build` executa o pipeline `targets`, normaliza layouts anuais e produz Parquet/RDS; nenhum produto é escrito sem o gate de qualidade aprovado.
5. `check` testa parser, harmonização, métricas, patrimônio, tributação, helpers dos relatórios e módulos do app.
6. `render`/`site` geram o site em `output/site`.

## Publicação (cômputo local, site estático)

Os dados brutos e o store do `targets` nunca vão ao repositório. O git carrega apenas código, dicionários, o `_freeze/` dos relatórios (resultados já computados) e o bundle curado do painel (~1 MB). A cada push na `main`, o workflow [`deploy-pages.yml`](.github/workflows/deploy-pages.yml) renderiza o site a partir do freeze, exporta o painel shinylive e publica no GitHub Pages — sem precisar dos dados nem de servidor.

**Regra de ouro:** após editar relatórios ou reconstruir dados, rode `run.cmd render` localmente antes do push (o CI falha se o freeze estiver desatualizado). O fluxo completo está em [`docs/operations.md`](docs/operations.md).

Espelho opcional: como `output/site` é um site estático completo, ele pode ser espelhado em qualquer CDN (ex.: `netlify deploy --dir=output/site`).

## Reprodutibilidade e segurança

- Dados brutos, `_targets/`, bibliotecas locais e `output/` não são versionados no Git.
- URLs, hashes, dicionários, documentação, `_freeze/` e o bundle do painel são versionados.
- Tokens de CI devem permanecer em variáveis de ambiente ou cofres de segredos; nenhum segredo é necessário para o deploy do Pages.
- Nenhuma atualização anual é publicada automaticamente: `source-monitor.yml` apenas detecta novas edições.

## Licença e citação

Código sob [MIT](LICENSE); textos, relatórios e site sob [CC BY 4.0](LICENSE-docs.md). Os dados originais pertencem à Receita Federal do Brasil e ao IBGE. Para citar, use os metadados de [`CITATION.cff`](CITATION.cff).

## Fontes principais

- [Distribuição de Renda por Centis — Receita Federal](https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/estudos/distribuicao-da-renda/distribuicao-de-renda-por-centis-estudo-ampliado-2017-a-2023)
- [Distribuição dos Bens e Direitos por Centis — Receita Federal](https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/estudos/distribuicao-da-renda/distribuicao-dos-bens-e-direitos-por-centis-de-2006-a-2021)
- IBGE/SIDRA para IPCA, população e contextualização.
