# Distribuição de renda e patrimônio no IRPF por centis

[![Publicar site](https://github.com/patrick-andrade/irpf-centis/actions/workflows/deploy-pages.yml/badge.svg)](https://github.com/patrick-andrade/irpf-centis/actions/workflows/deploy-pages.yml)
[![CI](https://github.com/patrick-andrade/irpf-centis/actions/workflows/ci.yml/badge.svg)](https://github.com/patrick-andrade/irpf-centis/actions/workflows/ci.yml)

Estudo descritivo e reprodutível da distribuição de renda, tributação e patrimônio entre declarantes do Imposto de Renda da Pessoa Física, por centis, anos-calendário e unidades da Federação. Parte das tabelas agregadas publicadas pela Receita Federal e entrega relatórios, um painel interativo e os dados curados que sustentam cada número.

**Site publicado:** <https://patrick-andrade.github.io/irpf-centis/>

> **Universo dos dados.** Os resultados descrevem **declarações válidas do IRPF**, não toda a população brasileira. Uma declaração pode reunir titular, dependentes e declaração conjunta. Centis estaduais são posições relativas dentro de cada UF e não equivalem aos mesmos cortes monetários nacionais. Todos os indicadores são aproximações calculadas sobre dados agrupados.

## Estado do projeto

**Beta público — versão 0.3.0.** Os resultados estão publicados para escrutínio, e o método segue em revisão: indicadores podem ser recalculados e recortes podem mudar entre versões. Ao citar um número, registre a versão de onde ele veio e confira se houve revisão depois. O [apêndice técnico](https://patrick-andrade.github.io/irpf-centis/reports/technical-appendix.html) registra os pontos que já se sabe estarem em aberto.

As instruções de execução local do pipeline não fazem parte desta fase. O código, os contratos de dados e a metodologia estão publicados; para executar o pipeline ou colaborar, [abra uma issue](https://github.com/patrick-andrade/irpf-centis/issues).

## O que este repositório acrescenta

Os estudos oficiais por centis são publicados em planilhas cujo layout muda de ano para ano, e os indicadores de desigualdade precisam ser calculados por quem os usa. Aqui esse trabalho está feito e versionado: a aquisição registra a procedência de cada arquivo, o pipeline é auditável ponta a ponta e cada valor publicado é rastreável até a fonte original.

Nenhum produto é escrito sem que os portões de qualidade passem: chaves únicas, contagem de grupos, reconciliação hierárquica dos centis, faixas plausíveis dos indicadores derivados e identidade dos totais patrimoniais. Divergências que existem na própria fonte oficial são preservadas e exportadas como avisos, nunca corrigidas em silêncio.

Os arquivos oficiais não são redistribuídos aqui: `data/metadata/sources-manifest.csv` registra a URL, a data de recuperação e o SHA-256 de cada um, para que sejam buscados na origem.

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

## Como está construído

Pipeline em R orquestrado por [`targets`](https://books.ropensci.org/targets/), com aquisição verificada por SHA-256, harmonização dos layouts anuais contra contratos declarados em `config/schema/`, testes automatizados e portões de qualidade entre o cálculo e a publicação. Relatórios em Quarto; painel em Shiny, exportado para shinylive e servido como site estático no GitHub Pages — roda no navegador do leitor, sem servidor.

## Contribuir e tirar dúvidas

Correções, apontamentos de erro e dúvidas de método são bem-vindos: abra uma [issue](https://github.com/patrick-andrade/irpf-centis/issues). Para um valor que não fecha, informe o recorte (ano, geografia, conceito de renda, grupo) e contra o quê a comparação foi feita.

[CONTRIBUTING.md](CONTRIBUTING.md) traz o processo e as convenções de código. A participação segue o [Código de Conduta](CODE_OF_CONDUCT.md); vulnerabilidades têm canal próprio em [SECURITY.md](SECURITY.md).

## Licença e citação

Código sob [MIT](LICENSE); textos, relatórios, site, dicionários de esquema e dados curados sob [CC BY-SA 4.0](LICENSE-docs.md) — reuso permitido, inclusive comercial, desde que com crédito e sob a mesma licença. Os dados originais pertencem à Receita Federal do Brasil e ao IBGE, e não são redistribuídos aqui.

Para citar, use os metadados de [`CITATION.cff`](CITATION.cff) e registre a versão: o projeto está em beta e os números podem ser revistos entre versões.

## Fontes

- [Distribuição de Renda por Centis — Receita Federal](https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/estudos/distribuicao-da-renda/distribuicao-de-renda-por-centis-estudo-ampliado-2017-a-2023)
- [Distribuição dos Bens e Direitos por Centis — Receita Federal](https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/estudos/distribuicao-da-renda/distribuicao-dos-bens-e-direitos-por-centis-de-2006-a-2021)
- IBGE/SIDRA, para o IPCA, população e contextualização.
