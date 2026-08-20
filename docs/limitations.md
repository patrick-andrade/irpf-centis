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
