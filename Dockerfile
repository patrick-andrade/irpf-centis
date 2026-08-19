# Seguro de migração para hospedagem com servidor Shiny (Posit Connect,
# Shiny Server ou VPS). O deploy oficial atual é estático (GitHub Pages +
# shinylive) e NÃO usa esta imagem; ela não é construída em CI.
# Requer app/data/app-bundle.rds presente (gerado por `run.cmd build`).
FROM rocker/shiny:4.6.0

RUN R -q -e "install.packages(c('bslib','bsicons','dplyr','ggplot2','scales','readr','tibble'), repos = 'https://cloud.r-project.org')"

WORKDIR /srv/irpf-centis
COPY app app

EXPOSE 3838
CMD ["R", "-q", "-e", "shiny::runApp('app', host = '0.0.0.0', port = 3838)"]
