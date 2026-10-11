# Página de glossário do site (glossario.qmd), gerada dos contratos
# config/schema/rankings.csv, indicators.csv e references.csv. Cada conceito e
# cada indicador ganha uma âncora estável (#conceito-RB4, #indicador-gini_grouped)
# para onde apontam os "?" e os quadros de conceitos das páginas Explorar.

ancora_conceito <- function(id) paste0("conceito-", id)
ancora_indicador <- function(id) paste0("indicador-", id)

texto_ou_nada <- function(x) {
  if (length(x) == 0L || is.na(x) || !nzchar(x)) NULL else as.character(x)
}

referencias_markdown <- function(chaves, referencias) {
  chaves <- unique(unlist(strsplit(stats::na.omit(chaves), ";", fixed = TRUE)))
  linhas <- referencias[match(chaves, referencias$key), , drop = FALSE]
  linhas <- linhas[!is.na(linhas$key), , drop = FALSE]
  if (nrow(linhas) == 0L) return(character())
  vapply(seq_len(nrow(linhas)), function(i) {
    destino <- if (!is.na(linhas$doi[[i]])) {
      sprintf(" [doi:%s](https://doi.org/%s)", linhas$doi[[i]], linhas$doi[[i]])
    } else if (!is.na(linhas$url[[i]])) {
      sprintf(" [Acessar](%s)", linhas$url[[i]])
    } else {
      ""
    }
    paste0("- ", linhas$citation[[i]], destino)
  }, character(1))
}

glossario_markdown <- function(rankings = read_schema("rankings"),
                               indicadores = read_schema("indicators"),
                               referencias = read_schema("references")) {
  anos <- function(linha) {
    if (is.na(linha$year_max)) paste0(linha$year_min, " em diante") else paste0(linha$year_min, " a ", linha$year_max)
  }
  conceitos <- unlist(lapply(seq_len(nrow(rankings)), function(i) {
    r <- rankings[i, , drop = FALSE]
    c(
      sprintf("### %s (%s) {#%s}", r$label, r$ranking_id, ancora_conceito(r$ranking_id)),
      "",
      if (isTRUE(r$primary == 1)) c("*Conceito central do estudo.*", "") else NULL,
      paste0("**Composição:** ", r$formula),
      "",
      r$definition,
      "",
      paste0("Tabela ", r$roman, " da Receita Federal; anos-calendário de ", anos(r), "."),
      ""
    )
  }))
  fichas <- unlist(lapply(seq_len(nrow(indicadores)), function(i) {
    ind <- indicadores[i, , drop = FALSE]
    refs <- referencias_markdown(ind$reference_keys, referencias)
    c(
      sprintf("### %s {#%s}", ind$short_label, ancora_indicador(ind$indicator_id)),
      "",
      ind$definition,
      "",
      if (!is.null(texto_ou_nada(ind$reading))) c(paste0("**Como ler:** ", ind$reading), "") else NULL,
      if (!is.null(texto_ou_nada(ind$range))) c(paste0("**Faixa:** ", ind$range), "") else NULL,
      if (!is.null(texto_ou_nada(ind$grouped_note))) c(paste0("**Cálculo com dados agrupados:** ", ind$grouped_note), "") else NULL,
      if (isTRUE(ind$unstable == 1)) {
        c("**Atenção:** indicador não limitado por construção; não comparar entre geografias sem checar a mediana do grupo.", "")
      } else NULL,
      if (length(refs) > 0L) c("**Referências:**", "", refs, "") else NULL
    )
  }))
  todas <- referencias_markdown(paste(referencias$key, collapse = ";"), referencias)
  c(
    "## Conceitos de renda {#conceitos}",
    "",
    "Cada conceito é uma ordenação diferente das mesmas declarações. O conceito central do estudo é a RB4; os demais servem de contraste.",
    "",
    conceitos,
    "## Indicadores {#indicadores}",
    "",
    "Todos os índices são calculados sobre as médias e as quantidades dos grupos divulgados. Como não há informação dentro de cada grupo, eles omitem a desigualdade intragrupo e devem ser lidos como aproximações.",
    "",
    fichas,
    "## Referências {#referencias}",
    "",
    "Fontes dos dados e literatura que sustenta as fórmulas dos indicadores. As mesmas chaves alimentam a bibliografia dos relatórios.",
    "",
    todas,
    ""
  )
}
