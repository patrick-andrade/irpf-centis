#!/usr/bin/env Rscript

# Exporta o painel Shiny como site estático WebAssembly (shinylive).
# Deve rodar DEPOIS de `quarto render`, porque o render limpa output/site.
options(encoding = "UTF-8")
shinylive::export("app", "output/site/app")
cat("Painel exportado para output/site/app\n")
