# Fontes e universo: verificação de setembro de 2026

Este registro público distingue o que a fonte afirma, o que o projeto calcula
e o que ainda precisa de ressalva. Os arquivos originais permanecem fora do
repositório; o [manifesto](../../data/metadata/sources-manifest.csv) permite
conferir URL, data, tamanho e SHA-256.

| Tema | Evidência | Implicação para os resultados |
|---|---|---|
| Integridade dos insumos locais | Os 53 caminhos do manifesto estavam presentes na revisão e os 53 SHA-256 coincidiam. São 49 registros da coleção de renda e quatro da coleção patrimonial. | Confirma a correspondência dos arquivos locais com o manifesto versionado; não atesta que a Receita não tenha atualizado a página depois da coleta. |
| Unidade e cobertura | O [metadado oficial de 2024](https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/estudos/distribuicao-da-renda/distribuicao-de-renda-por-centis-estudo-ampliado-2017-a-2023/2024/metadados-centis-ac2024.pdf) descreve declarações válidas e exclui valores distorcidos. | Os percentis representam declarações, não pessoas ou toda a população. |
| Regra específica de RB9 | Na Tabela X do mesmo metadado, a Receita registra exclusão das declarações com RB9 superior a R$ 100 milhões. | A regra precisa aparecer junto à comparação de RB9 com outros rankings em 2024. A nota oficial, por si só, não quantifica quantas declarações foram afetadas. |
| Grupos disjuntos | A Receita subdivide o centil superior; o projeto usa os 118 grupos folha e reserva 100/110 para reconciliação. | Não somar grupos agregados e seus descendentes. Conferir pesos e totais por ranking e geografia. |
| 2018 | A [limitação documentada](../limitations.md) registra valor excepcional no grupo 120 da fonte oficial e a sensibilidade sem esse grupo. | Tratar comparações interanuais de 2018 com ressalva visível; preservar o valor oficial e a variante analítica separadamente. |
| Cobertura incompleta | O contrato de disponibilidade identifica SP–RB9 ausente em 2023; as Tabelas I e II da coleção patrimonial são baixadas, mas a série patrimonial direta usa a Tabela III. | Não imputar a lacuna nem apresentar a coleção patrimonial como integralmente ingerida. |

Para cada número publicado, o caminho de verificação é: URL e hash no
manifesto → layout e ranking em `config/schema/` → grupo disjunto e chave
ano/geografia/ranking nos dados curados → fórmula do indicador → tabela ou
gráfico. As [definições](../methodology.md), [limitações](../limitations.md) e
o [dicionário](../data-dictionary.md) são a referência de leitura do resultado.

**Pendente de verificação por edição:** a nota de exclusão RB9 foi confirmada
no metadado de 2024. Sua aplicação e magnitude nos outros anos não devem ser
inferidas a partir desse documento.
