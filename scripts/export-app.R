#!/usr/bin/env Rscript

# Exporta o painel Shiny como site estático WebAssembly (shinylive).
# Deve rodar DEPOIS de `quarto render`, porque o render limpa output/site.
# É o mesmo script no `run.cmd site` e no job de publicação, que o chama sem as
# dependências do pipeline: por isso só lê R/outputs.R, cujos helpers de export
# usam base R e o jsonlite que vem com o shiny.
options(encoding = "UTF-8")
if (!exists("parametros_index_painel")) source("R/outputs.R", encoding = "UTF-8")

destino <- "output/site/app"
shinylive::export("app", destino, template_params = parametros_index_painel())
ajustar_index_painel(file.path(destino, "index.html"))
conferir_pacotes_painel(destino)
conferir_versoes_painel(destino)
cat("Painel exportado para", destino, "\n")
