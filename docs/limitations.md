---
title: "Limitações"
---

1. O universo contém declarantes do IRPF, não a população brasileira completa.
2. Declarações conjuntas e dependentes impedem interpretar cada declaração como uma pessoa.
3. Dados agrupados não revelam variação dentro dos grupos.
4. A base da Receita é dinâmica e pode mudar após retificações.
5. Definições e layouts podem variar entre anos.
6. Centis de UFs são ordenados dentro de cada UF.
7. Valores de bens declarados seguem regras fiscais e não equivalem necessariamente a preços de mercado.
8. O estudo é descritivo e não identifica efeitos causais.
9. Nos arquivos de 2017–2021, as somas monetárias dos estratos detalhados da RTB não reconciliam com os agregados 100/110 em 28 geografias subnacionais/exterior, embora as contagens de contribuintes reconciliem exatamente. O projeto preserva os valores publicados e registra cada diferença em `data/processed/hierarchy-reconciliation.csv`; não aplica correção silenciosa.
10. A combinação SP–RB9 não está presente no arquivo regional oficial de 2023. O projeto registra a lacuna no gate `series_coverage` e não imputa dados.
11. As participações de topo somam grupos disjuntos divulgados, sem interpolação intragrupo; a adoção de interpolação de Pareto generalizada (Blanchet–Fournier–Piketty) permanece na agenda de pesquisa do projeto.
12. As Tabelas I e II da coleção patrimonial são baixadas e verificadas por hash, mas não são ingeridas; apenas a Tabela III (ordenação direta nacional) alimenta a série de desigualdade patrimonial.
13. **O ano-calendário 2018 não é comparável aos demais.** No arquivo oficial de 2018, o grupo 120 (top 0,01%, 3.181 declarações) traz soma de RB4 de R$ 948,3 bilhões e média de R$ 298,1 milhões por declaração, contra R$ 115,5 bilhões e R$ 37,9 milhões em 2017 e R$ 162,5 bilhões e R$ 49,0 milhões em 2019. O limite superior publicado do grupo é R$ 320.000.008.402,81, ante R$ 1,75 bilhão em 2017 e R$ 5,12 bilhões em 2019. Os 117 demais grupos de 2018 seguem a tendência dos anos vizinhos. Esse único grupo eleva o Gini nacional da RB4 de 0,584 para 0,666 e a participação do top 1% de 20,9% para 36,9%, e o efeito aparece em todos os conceitos de renda. Os valores são os publicados pela Receita Federal e foram conferidos célula a célula contra o arquivo de origem; o projeto os preserva sem correção, sinaliza o ano no gate `gini_year_over_year` e apresenta, junto às séries, a variante calculada sem o grupo 120.
14. A alíquota efetiva média só é interpretável quando o conceito de renda do ranking contém a renda tributada. Nos conceitos estreitos (RB5, RB9, RB10) um grupo pode ter renda do conceito próxima de zero e ainda dever imposto sobre rendimentos fora dele; nesses casos a razão fica `NA` em vez de produzir alíquotas de milhares por cento. As colunas `tax_due` e `rank_sum` permanecem íntegras, e o gate `effective_rate_coverage` registra quantos grupos ficaram sem razão publicável. Sob RB4, conceito central do estudo, 97% dos grupos têm alíquota definida.
