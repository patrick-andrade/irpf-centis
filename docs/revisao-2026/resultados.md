# Resultado da comparação numérica

Comparação realizada após executar o pipeline com as fontes listadas no
manifesto e o cache de parse dessas planilhas, cujos arquivos de origem tiveram
seus SHA-256 conferidos. O snapshot anterior e o novo foram cotejados por SHA-256 e, quando
o arquivo mudou, por esquema, coluna e linha. O baseline é o estado público de
partida `e9a8eff5336c66403df802e6a815cd5e57811033`; esta revisão fica
identificada pelo commit que a integrar.

| Produto | Diferença verificada |
|---|---|
| Nove dos 12 arquivos curados | Idênticos byte a byte: contexto de cobertura, grupos de renda, alíquota efetiva, reconciliação, componentes de renda, decomposição de Theil, contagens de topo, bens por grupo de renda e série patrimonial direta. |
| `distribution-metrics.parquet` | Mesmas 2.406 linhas e chaves. Só `wolfson_grouped` mudou: 1.912 valores finitos; nenhum novo `NA` nas participações de renda. Para Brasil–RB4 em 2024, 0,92206242 → 0,47504184. A maior diferença absoluta, 5.860,83, ocorre em recorte de mediana próxima de zero e não deve ser lida como variação econômica. |
| `wealth-metrics.parquet` | Mesmas 16 linhas. Wolfson mudou nas 16; cinco participações de topo/base e Palma passaram a `NA` nas 16 porque os cortes cruzam grupos divulgados. Em 2021, um `top_1_share` calculado a partir de apenas 0,65073% das declarações e Palma de 10.322,97 deixam de ser apresentados como estimativas válidas. Gini patrimonial permanece igual. |
| `quality-checks.csv` | Estados de aprovação/aviso inalterados. Dois detalhes mudaram: redação do gate de códigos 1–120 e contagem de avisos por índice instável, de 200 para 118 após corrigir Wolfson. |

O bundle do painel conserva sem alteração os 10.121 grupos de composição de
renda, as 27.376 linhas de alíquota efetiva RB4, as 27.376 de bens por grupo,
as 928 contagens de topo, a decomposição, a geometria, as geografias, os
rankings e as referências. As alterações de valor nele correspondem às
métricas de renda e patrimônio descritas acima; o timestamp de geração também
muda. As notas textuais dos indicadores acompanham os contratos versionados.

**Interpretação:** a [fórmula corrigida](../methodology.md) usa a normalização
pela mediana em toda a expressão de Foster–Wolfson, conforme o
[manual da Statistics Canada](https://www23.statcan.gc.ca/imdb-bmdi/document/3889_DLI_D1_T22_V8-eng.pdf).
Em conceitos estreitos com mediana próxima de zero, diferenças absolutas do
índice podem ser muito grandes; o relatório não deve tratá-las como evolução
econômica substantiva. A série patrimonial direta mantém o Gini e deixa
ausentes as participações que exigiriam interpolação intragrupo.

A versão 0.3.0 arquivada com DOI permanece intacta. O site atualizado deve ser
citado com data e commit quando o valor diferir da versão arquivada.
