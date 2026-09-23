# Diagnóstico de práticas do projeto

O estudo é uma análise descritiva de declarações de IRPF agrupadas pela
Receita. A avaliação usa como referência a rastreabilidade dos insumos, a
clareza da unidade estatística, a fidelidade das fórmulas, a reprodução dos
resultados, a interpretação econômica e a apresentação honesta das incertezas.
Ela não trata os números como estimativas da distribuição de toda a população.

| Dimensão | Situação encontrada | Ação nesta revisão |
|---|---|---|
| Fontes | Manifesto com URL, data, tamanho e SHA-256; 53 arquivos locais conferidos. O fluxo de download ainda podia atualizar um hash conhecido sem comparação. | Proteger a troca de fonte e registrar o desvio. |
| Unidade e universo | O texto público afirma genericamente que cada ranking ordena as mesmas declarações. O metadado oficial de 2024 explicita uma exclusão para RB9 acima de R$ 100 milhões. | Acrescentar ressalva por ranking e limitar afirmações ao que a fonte e as contagens permitem concluir. |
| Indicadores | Contratos e testes cobrem os índices agrupados e a reconciliação. A fórmula de Foster–Wolfson aplicada antes da revisão difere da forma publicada pela [Statistics Canada](https://www23.statcan.gc.ca/imdb-bmdi/document/3889_DLI_D1_T22_V8-eng.pdf). | Corrigir cálculo, equação, série derivada e teste sintético; documentar diferença numérica. |
| Dados agrupados | O Gini vem com limites e os grupos disjuntos são definidos; 2018 tem grupo superior excepcional na fonte. | Manter o valor oficial e destacar a sensibilidade no gráfico e na interpretação. Não acrescentar interpolação de Pareto sem estudo próprio. |
| Reprodutibilidade | `renv.lock`, contratos, testes, freeze e bundle estão versionados; o CI não reconstrói os dados brutos, e o README não explicava a execução local. | Publicar [passos de reprodução](../reproducibility.md), testar ambiente restaurado e anotar o alcance de CI e render. |
| Lint | `check` executava `lintr::lint_dir()`, mas descartava o retorno. O primeiro diagnóstico contou 705 apontamentos em `R/` e 500 em `app/R`; após as correções e revisão do PR, 562 e 366. O código anterior já não cumpria um gate de lint. | Registrar a dívida e evitar apresentar `check` verde como prova de lint aprovado. Uma política de lint viável requer linha de base ou limpeza própria. |
| Comunicação | O site era predominantemente o tema padrão Quarto e documentos de contribuição tinham regras extensas para o porte do projeto. | Simplificar contribuição e aplicar hierarquia visual consistente a site, relatórios e painel. |

Como comparação metodológica, a [WID](https://wid.world/methodology/) integra
fontes fiscais e outras bases para estimar distribuições mais amplas. Aqui o
universo permanece o das declarações divulgadas pela Receita; os níveis e
participações deste estudo não devem ser apresentados como equivalentes a
estimativas DINA ou da população adulta inteira.

Este diagnóstico registra o ponto de partida. O resultado das verificações e
as diferenças numéricas ficam no registro de integração desta mesma pasta.
