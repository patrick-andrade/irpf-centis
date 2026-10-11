# Reproduzir a análise

O repositório contém código, contratos, testes, manifesto das fontes e saídas
curadas necessárias ao site estático. As planilhas oficiais não são
redistribuídas: devem ser obtidas da Receita Federal pelos endereços em
[`sources-manifest.csv`](../data/metadata/sources-manifest.csv). O arquivo
registra também tamanho e SHA-256 de cada fonte. Para reproduzir uma versão
citada, comece pelo commit correspondente e confira esses hashes antes de
comparar resultados.

Use R 4.6, Quarto 1.9.38 (a mesma versão fixada no CI e na publicação), Node
24 (versão em `.nvmrc`) e as dependências registradas em `renv.lock` e
`package-lock.json`. Na raiz do projeto:

```sh
Rscript -e "renv::restore(prompt=FALSE)"
npm ci
Rscript scripts/run.R download
Rscript scripts/run.R context
Rscript scripts/run.R build
Rscript scripts/run.R check
Rscript scripts/run.R render
```

`download` usa o inventário versionado em `data/metadata/sources-discovered.csv`.
`discover` atualiza esse inventário para a situação corrente da página da
Receita; revise qualquer mudança antes de usá-lo para uma réplica histórica.
Os dados intermediários e brutos ficam fora do Git. `build` produz os arquivos
em `data/processed/` e os dados das páginas Explorar em `explorar/dados/`
(JSON e CSV, versionados). `check` roda os testes R e, com Node, os testes do
módulo JavaScript (`npm test`). `render` gera o bundle das páginas
(`assets/js/irpf-viz.js`) e as figuras dos relatórios (`reports/figuras/`) e
renderiza HTML e PDF em `output/site/`. No Windows, os mesmos comandos podem
ser chamados por `run.cmd`.

Para ver o site como no GitHub Pages, sob o subcaminho `/irpf-centis/`:

```sh
node scripts/servir.mjs output/site
npm run smoke
npm run medir
```

`smoke` abre cada página num Chrome ou Edge instalado (variável `NAVEGADOR` para
escolher o executável) e confere erros, links, CSV e acessibilidade; `medir`
mede o tempo até o primeiro gráfico.

A publicação só repete o render do Quarto sobre o que está versionado
(`_freeze/`, `explorar/dados/`, `assets/js/`, `reports/figuras/`): não executa
R nem Node. Mudou um dado ou um gráfico? Rode `build` e `render` localmente e
commite os arquivos gerados; o CI regenera o bundle e as figuras e falha se
divergirem do que foi commitado.

O site publicado pode mudar entre commits sem que um DOI arquivado seja
substituído. Para conferir um número citado, registre também o commit ou a data
de consulta. O [método](methodology.md), as [limitações](limitations.md) e a
[proveniência](provenance.md)
explicam as escolhas e ressalvas de leitura.
