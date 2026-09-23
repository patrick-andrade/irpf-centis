# Reproduzir a análise

O repositório contém código, contratos, testes, manifesto das fontes e saídas
curadas necessárias ao site estático. As planilhas oficiais não são
redistribuídas: devem ser obtidas da Receita Federal pelos endereços em
[`sources-manifest.csv`](../data/metadata/sources-manifest.csv). O arquivo
registra também tamanho e SHA-256 de cada fonte. Para reproduzir uma versão
citada, comece pelo commit correspondente e confira esses hashes antes de
comparar resultados.

Use R 4.6, Quarto (esta revisão foi verificada com 1.9.38) e as dependências
registradas em `renv.lock`. Na raiz do projeto:

```sh
Rscript -e "renv::restore(prompt=FALSE)"
Rscript scripts/run.R download
Rscript scripts/run.R context
Rscript scripts/run.R build
Rscript scripts/run.R check
Rscript scripts/run.R site
```

`download` usa o inventário versionado em `data/metadata/sources-discovered.csv`.
`discover` atualiza esse inventário para a situação corrente da página da
Receita; revise qualquer mudança antes de usá-lo para uma réplica histórica.
Os dados intermediários e brutos ficam fora do Git. `build` produz os arquivos
em `data/processed/`; `site` renderiza HTML e PDF e exporta o painel estático
para `output/site/`. No Windows, os mesmos comandos podem ser chamados por
`run.cmd`.

O site publicado pode mudar entre commits sem que um DOI arquivado seja
substituído. Para conferir um número citado, registre também o commit ou a data
de consulta. O [método](methodology.md), as [limitações](limitations.md) e a
[proveniência no repositório](https://github.com/patrick-andrade/irpf-centis/blob/main/docs/provenance.md)
explicam as escolhas e ressalvas de leitura.
