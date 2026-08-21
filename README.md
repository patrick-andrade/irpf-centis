# Distribuição de renda e patrimônio no IRPF por centis

[![Publicar site](https://github.com/patrick-andrade/irpf-centis/actions/workflows/deploy-pages.yml/badge.svg)](https://github.com/patrick-andrade/irpf-centis/actions/workflows/deploy-pages.yml)
[![CI](https://github.com/patrick-andrade/irpf-centis/actions/workflows/ci.yml/badge.svg)](https://github.com/patrick-andrade/irpf-centis/actions/workflows/ci.yml)

Estudo descritivo e reprodutível da distribuição de renda, tributação e patrimônio entre declarantes do Imposto de Renda da Pessoa Física, por centis, anos-calendário e unidades da Federação. Parte das tabelas agregadas publicadas pela Receita Federal e entrega relatórios, um painel interativo e os dados curados que sustentam cada número.

**Site publicado:** <https://patrick-andrade.github.io/irpf-centis/>

> **Universo dos dados.** Os resultados descrevem **declarações válidas do IRPF**, não toda a população brasileira. Uma declaração pode reunir titular, dependentes e declaração conjunta. Centis estaduais são posições relativas dentro de cada UF e não equivalem aos mesmos cortes monetários nacionais. Todos os indicadores são aproximações calculadas sobre dados agrupados.

## O que este repositório acrescenta

Os estudos oficiais por centis são publicados em planilhas cujo layout muda de ano para ano, e os indicadores de desigualdade precisam ser calculados por quem os usa. Aqui esse trabalho está feito e versionado: a aquisição registra a procedência de cada arquivo, o pipeline é auditável ponta a ponta e o cálculo de cada valor publicado pode ser refeito a partir das fontes originais.

## O que o estudo cobre

- **Renda:** anos-calendário 2017–2024, com o conceito RB4 como lente principal (rendimentos tributáveis, isentos e de tributação exclusiva ou definitiva, excluídas doações e heranças) e RTB, RB3 e RB5 como contrastes.
- **Patrimônio:** bens e dívidas ao longo da distribuição de renda em 2017–2024 e a série nacional de ordenação direta por bens e direitos em 2006–2021.
- **Geografias:** Brasil, as 27 unidades da Federação e declarantes no exterior.
- **Indicadores:** Gini agrupado com limites de Gastwirth, Theil T, Atkinson (ε = 0,5 e 1), Wolfson, Esteban–Ray, participações de topo e base, Palma, P90/P50, alíquota efetiva média e decomposição de Theil por UF.
- **Valores monetários:** em reais de 2024, deflacionados pelo IPCA anual; os nominais ficam preservados nos dados curados.

## O que você encontra

| | |
|---|---|
| [Painel interativo](https://patrick-andrade.github.io/irpf-centis/app/) | Indicadores por ano, geografia e conceito de renda, mapa por UF, composição de rendimentos, alíquota efetiva, bens e dívidas. Roda inteiramente no navegador (shinylive/WebAssembly), sem servidor. |
| [Relatório completo](https://patrick-andrade.github.io/irpf-centis/reports/report.html) | Evolução nacional, tipos de rendimento, tributação, patrimônio, estados e regiões, robustez e limitações. |
| [Sumário executivo](https://patrick-andrade.github.io/irpf-centis/reports/executive-summary.html) | Principais achados em formato curto. |
| [Apêndice técnico](https://patrick-andrade.github.io/irpf-centis/reports/technical-appendix.html) | Contratos de dados, fórmulas, validações e proveniência. |
| [Metodologia](docs/methodology.md) · [limitações](docs/limitations.md) | O método completo e o que estes números não conseguem dizer. |
| [Dicionário de dados](docs/data-dictionary.md) · [proveniência](docs/provenance.md) | O contrato de cada tabela e a rastreabilidade até o arquivo oficial. |
| [Decisões conceituais](docs/decisions) | Registros das escolhas que sustentam as leituras publicadas — universo, conceito de renda. |

Os relatórios também estão disponíveis em PDF, pelo link "Outros formatos" de cada página.

## Reproduzir localmente

### Pré-requisitos

- R 4.6.0
- Quarto 1.9 ou superior
- Dependências restauradas com `renv::restore()`

### Passo a passo

```bash
./run.sh discover        # lê as páginas oficiais e inventaria as fontes
./run.sh download 2024   # baixa os arquivos e registra tamanho e SHA-256
./run.sh context         # baixa os deflatores do IPCA e a malha estadual do IBGE
./run.sh build           # executa o pipeline targets e grava os dados curados
./run.sh check           # roda testes e validações
./run.sh site            # renderiza o site e exporta o painel em output/site
./run.sh app             # abre o painel Shiny localmente
```

No Windows, use `run.cmd` no lugar de `./run.sh`. `run.cmd help` lista todos os comandos.

O pipeline não escreve nenhum produto sem que os portões de qualidade passem: chaves únicas, contagem de grupos, reconciliação hierárquica dos centis, faixas plausíveis dos indicadores derivados e identidade dos totais patrimoniais. Divergências que existem na própria fonte oficial são preservadas e exportadas como avisos, nunca corrigidas em silêncio.

### O que o Git carrega

Versionado: código, dicionários de esquema, documentação, o `_freeze/` dos relatórios (resultados já computados) e o bundle curado do painel. Fora do Git: dados brutos, o store do `targets`, bibliotecas locais e `output/`. Isso mantém o clone leve e faz o site publicar sem precisar dos dados originais.

Os arquivos oficiais não são redistribuídos aqui — `data/metadata/sources-manifest.csv` traz a URL, a data de recuperação e o SHA-256 de cada um, e `./run.sh download` os busca na origem.

### Como o site é publicado

A cada push na `main`, o workflow [`deploy-pages.yml`](.github/workflows/deploy-pages.yml) renderiza o site a partir do freeze, exporta o painel shinylive e publica no GitHub Pages. O resultado é um site estático completo: não há servidor, banco nem segredo envolvido. `source-monitor.yml` apenas avisa quando a Receita publica uma nova edição — nada é republicado automaticamente.

## Contribuir e tirar dúvidas

Correções, apontamentos de erro e dúvidas de método são bem-vindos: abra uma [issue](https://github.com/patrick-andrade/irpf-centis/issues). Para um valor que não fecha, informe o recorte (ano, geografia, conceito de renda, grupo) e contra o quê a comparação foi feita.

[CONTRIBUTING.md](CONTRIBUTING.md) traz o processo e as convenções de código. A participação segue o [Código de Conduta](CODE_OF_CONDUCT.md); vulnerabilidades têm canal próprio em [SECURITY.md](SECURITY.md).

## Licença e citação

Código sob [MIT](LICENSE); textos, relatórios e site sob [CC BY 4.0](LICENSE-docs.md). Os dados originais pertencem à Receita Federal do Brasil e ao IBGE. Para citar, use os metadados de [`CITATION.cff`](CITATION.cff).

## Fontes

- [Distribuição de Renda por Centis — Receita Federal](https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/estudos/distribuicao-da-renda/distribuicao-de-renda-por-centis-estudo-ampliado-2017-a-2023)
- [Distribuição dos Bens e Direitos por Centis — Receita Federal](https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/estudos/distribuicao-da-renda/distribuicao-dos-bens-e-direitos-por-centis-de-2006-a-2021)
- IBGE/SIDRA, para o IPCA, população e contextualização.
