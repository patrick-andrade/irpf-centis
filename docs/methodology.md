---
title: "Metodologia"
---

## Unidade de observação

A unidade básica divulgada pela Receita Federal é a declaração válida do IRPF, que pode incluir titular, dependentes e declaração conjunta. Os resultados não representam diretamente pessoas, domicílios ou toda a população brasileira.

## Conceito principal de renda

RB4 ordena as declarações pela soma dos rendimentos tributáveis, isentos e sujeitos à tributação exclusiva ou definitiva, retirando transferências patrimoniais como doações e heranças. RTB, RB3 e RB5 são análises de contraste.

## Conceitos de renda disponíveis

Cada conceito é uma ordenação diferente das mesmas declarações, publicada pela Receita Federal em uma tabela própria. O contrato executável está em `config/schema/rankings.csv` e alimenta tanto os relatórios quanto o painel.

| Tabela | Código | Conceito | Composição | Anos |
|---|---|---|---|---|
| I | RTB | Renda Tributável Bruta | Rendimentos tributáveis brutos | 2017- |
| II | RB1 | Renda ampliada 1 | RTB + rendimentos de sócio ou titular de MPE + lucros e dividendos | 2017- |
| III | RB2 | Renda ampliada 2 | RB1 + rendimentos sujeitos à tributação exclusiva ou definitiva | 2017- |
| IV | RB3 | Renda ampliada 3 | RB2 + parcelas isentas selecionadas | 2017- |
| V | RB4 | Renda ampla sem transferências patrimoniais | RTB + rendimentos isentos + rendimentos exclusivos ou definitivos − doações e heranças | 2017- |
| VI | RB5 | Rendimentos empresariais isentos | Lucros e dividendos + rendimentos de sócio ou titular de MPE do Simples | 2017- |
| VII | RB6 | Base e capital 1 | Base de cálculo + lucros e dividendos + aplicações financeiras + renda variável + aluguéis | 2017- |
| VIII | RB7 | Base e capital 2 | RB6 + rendimentos de sócio ou titular de MPE do Simples | 2017- |
| IX | RB8 | Base de cálculo | Base de cálculo do imposto de renda | 2017- |
| X | RB9 | Rendimentos do Simples | Rendimentos de sócio ou titular de MPE do Simples | 2017- |
| XI | RB10 | Desconto simplificado | Valor do desconto simplificado | 2022- |

Os índices de desigualdade e as notas metodológicas de cada indicador estão em `config/schema/indicators.csv`, com as referências bibliográficas em `config/schema/references.csv`, que espelha `reports/references.bib`.

## Grupos hierárquicos

Os grupos 100 e 110 são agregados que se sobrepõem aos detalhamentos subsequentes. A distribuição disjunta usada nos índices contém 1–99, 101–109 e 111–120. Os grupos 100 e 110 são preservados apenas para reconciliação e apresentação direta do top 1% e do top 0,1%.

## Índices agrupados

Gini, Theil T, Atkinson (ε = 0,5 e o caso-limite ε = 1 pela média geométrica), Wolfson e Esteban–Ray são calculados a partir das médias e quantidades dos grupos. Como não há informação dentro de cada grupo, esses valores são aproximações e, em medidas de desigualdade, normalmente omitem a desigualdade intragrupo. Para o Gini, além do limite inferior (trapézio de Lorenz sobre as médias), publica-se um limite superior no espírito de Gastwirth (1972), que soma a máxima desigualdade intragrupo compatível com as médias e os limites monetários divulgados; o intervalo `[gini_lower_bound, gini_upper_bound]` acompanha todas as distribuições.

## Alíquota efetiva

A alíquota efetiva média de cada grupo divide o imposto devido pela renda no conceito do próprio ranking. Sob RB4, que inclui rendimentos isentos e de tributação exclusiva, a curva mede a carga tributária sobre a renda ampla declarada, não sobre a base de cálculo legal. Grupos com renda nula ou não divulgada recebem `NA`, e a leitura permanece uma média de grupo.

## Geografia

Cada UF é ordenada separadamente pela Receita. O centil 90 de uma UF não possui necessariamente o mesmo limite monetário do centil 90 de outra. Mapas comparam indicadores calculados dentro de cada UF; não transformam centis estaduais em centis nacionais.

## Patrimônio

Nos arquivos ampliados, bens e direitos são observados dentro de grupos ordenados por renda. Isso mede concentração patrimonial ao longo da distribuição de renda. A expressão desigualdade patrimonial é reservada à série nacional ordenada diretamente pelo valor dos bens e direitos.

## Valores reais

Os fluxos e estoques monetários são publicados em preços de 2024, deflacionados pelo IPCA anual médio (IBGE/SIDRA 1737); os valores nominais são preservados nos dados curados. Os produtos editoriais e o painel rotulam explicitamente "R$ de 2024". O arquivo de deflatores registra fonte, método e índice anual utilizado, e a ausência de deflator para qualquer ano interrompe o pipeline em vez de degradar silenciosamente.

## Escopo inferencial

O projeto é descritivo. Mudanças anuais podem refletir alterações econômicas, tributárias, cadastrais, metodológicas ou de cobertura. Não serão apresentadas como efeitos causais sem um desenho de identificação externo a este projeto.

## Contexto populacional

O arquivo `coverage-context.csv` registra declarantes e IPCA por ano e geografia. A razão de cobertura permanece `NA` e marcada como `pending_ibge_adult_denominator` até que a definição exata de população adulta, a tabela SIDRA e o tratamento territorial sejam congelados em decisão metodológica. Nenhum denominador provisório entra nos produtos publicados, e não há fusão distributiva entre IRPF e PNAD.

## Endividamento

Dívidas e ônus são um saldo declarado no encerramento do ano-calendário; a renda do conceito de ordenação é um fluxo de doze meses. A razão entre os dois, publicada por grupo em `wealth_by_bin`, mede alavancagem declarada, e não capacidade de pagamento nem inadimplência. Onde a renda do grupo é nula a razão fica `NA`, pelo mesmo critério aplicado à alíquota efetiva. O total de bens da série é a soma das quatro famílias divulgadas — imóveis, móveis, ativos financeiros e outros —, porque o total consolidado só aparece na fonte a partir de 2022; nos anos em que os dois existem, o gate `asset_total_identity` confere um contra o outro.

## Contagens dos grupos de topo

Participação de topo é uma fração da renda; a quantidade de declarações por trás dela vem dos tamanhos de grupo publicados pela Receita, e não do total multiplicado pelo corte. A tabela `top_group_counts` soma as folhas disjuntas acima de cada limiar e registra, além das declarações, as declarações conjuntas e os dependentes. Declarações conjuntas só são divulgadas a partir do ano-calendário 2023; nos anos anteriores o campo permanece `NA` e é apresentado como não divulgado, nunca como zero.

## Como os dados curados são construídos

1. `discover` lê as páginas oficiais e registra o inventário de fontes.
2. `download` baixa os arquivos e grava tamanho e SHA-256 em `data/metadata/sources-manifest.csv`.
3. `context` atualiza o deflator IPCA anual e a malha estadual do IBGE.
4. `build` normaliza os layouts de cada ano e produz os dados curados. Dois portões de qualidade — estrutura da fonte e plausibilidade dos indicadores derivados — interrompem o pipeline em vez de degradar em silêncio.
5. `check` testa parser, harmonização, índices, patrimônio, tributação, os helpers dos relatórios e os módulos do painel.
6. `render` e `site` geram os relatórios e exportam o painel para WebAssembly.

Decisões que o pipeline não negocia: valores publicados pela Receita são preservados, e divergências são registradas em vez de corrigidas; campo ausente na fonte permanece ausente e não vira zero; os índices usam apenas os 118 grupos disjuntos; a ausência de deflator para qualquer ano interrompe a execução.

O código, os contratos de dados e os testes estão em <https://github.com/patrick-andrade/irpf-centis>.
