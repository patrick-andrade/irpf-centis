# Metodologia

## Unidade de observação

A unidade básica divulgada pela Receita Federal é a declaração válida do IRPF, que pode incluir titular, dependentes e declaração conjunta. Os resultados não representam diretamente pessoas, domicílios ou toda a população brasileira.

## Conceito principal de renda

RB4 ordena as declarações pela soma dos rendimentos tributáveis, isentos e sujeitos à tributação exclusiva ou definitiva, retirando transferências patrimoniais como doações e heranças. RTB, RB3 e RB5 são análises de contraste.

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
