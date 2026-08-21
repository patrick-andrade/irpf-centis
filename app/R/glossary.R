`%||%` <- function(x, y) if (is.null(x)) y else x

# Glossário do painel. Os textos não são escritos aqui: vêm dos contratos
# `config/schema/rankings.csv`, `indicators.csv` e `references.csv`, que entram
# no bundle. Este arquivo só decide como apresentá-los.
#
# Todas as funções degradam para NULL quando a fatia correspondente do bundle
# está vazia — é o caso da integração contínua, que roda sem os dados
# processados e ainda assim monta a UI.

schema_slice <- function(bundle, nome) {
  slice <- bundle[[nome]]
  if (is.null(slice) || nrow(slice) == 0L) NULL else slice
}

# Coluna que pode não existir num bundle gerado antes destes contratos.
coluna_opcional <- function(linha, nome) {
  if (!nome %in% names(linha)) return(NA_character_)
  valor <- linha[[nome]][[1]]
  if (is.na(valor) || !nzchar(valor)) NA_character_ else as.character(valor)
}

texto_conceito <- function(bundle, ranking_id) {
  rankings <- schema_slice(bundle, "rankings")
  if (is.null(rankings)) return(NULL)
  linha <- rankings[rankings$ranking_id == ranking_id, , drop = FALSE]
  if (nrow(linha) == 0L) return(NULL)
  list(
    termo = coluna_opcional(linha, "label") %||% ranking_id,
    resumo = coluna_opcional(linha, "formula"),
    detalhe = coluna_opcional(linha, "definition"),
    nota = NULL
  )
}

texto_indicador <- function(bundle, indicator_id) {
  indicadores <- schema_slice(bundle, "indicators")
  if (is.null(indicadores)) return(NULL)
  linha <- indicadores[indicadores$indicator_id == indicator_id, , drop = FALSE]
  if (nrow(linha) == 0L) return(NULL)
  list(
    termo = coluna_opcional(linha, "short_label") %||% indicator_id,
    resumo = coluna_opcional(linha, "definition"),
    detalhe = coluna_opcional(linha, "reading"),
    nota = coluna_opcional(linha, "grouped_note")
  )
}

# Termos que não têm linha em nenhum contrato — distinções editoriais do painel,
# como a diferença entre observar bens dentro dos centis de renda e ordenar
# diretamente pelo patrimônio.
texto_livre <- function(termo, resumo, detalhe = NULL, nota = NULL) {
  list(termo = termo, resumo = resumo, detalhe = detalhe, nota = nota)
}

item_glossario <- function(item) {
  if (is.null(item)) return(NULL)
  corpo <- list(
    if (!is.na(item$resumo %||% NA_character_)) shiny::tags$span(item$resumo),
    if (!is.na(item$detalhe %||% NA_character_)) {
      shiny::tags$span(class = "glossario-detalhe", item$detalhe)
    },
    if (!is.na(item$nota %||% NA_character_)) {
      shiny::tags$span(class = "glossario-nota", item$nota)
    }
  )
  shiny::tagList(
    shiny::tags$dt(item$termo),
    shiny::tags$dd(Filter(Negate(is.null), corpo))
  )
}

secao_glossario <- function(titulo, itens) {
  itens <- Filter(Negate(is.null), itens)
  if (length(itens) == 0L) return(NULL)
  shiny::tagList(
    shiny::tags$p(class = "glossario-titulo", titulo),
    shiny::tags$dl(class = "glossario-lista", lapply(itens, item_glossario))
  )
}

#' Quadro "Conceitos e indicadores" da base de cada aba.
#'
#' Fica depois dos gráficos, de propósito: explicar antes empurraria a
#' visualização para fora da primeira tela.
bloco_conceitos <- function(bundle, rankings = NULL, indicadores = NULL, extras = NULL,
                            adicional = NULL) {
  secoes <- list(
    secao_glossario(
      if (length(rankings) > 1L) "Conceitos de renda:" else "Conceito de renda:",
      lapply(rankings, function(id) texto_conceito(bundle, id))
    ),
    secao_glossario(
      if (length(indicadores) > 1L) "Indicadores:" else "Indicador:",
      lapply(indicadores, function(id) texto_indicador(bundle, id))
    ),
    secao_glossario("Como ler esta aba:", extras),
    adicional
  )
  secoes <- Filter(Negate(is.null), secoes)
  if (length(secoes) == 0L) return(NULL)
  bslib::card(
    class = "bloco-conceitos",
    bslib::card_header("Conceitos e indicadores"),
    secoes
  )
}

linha_rodape <- function(rotulo, textos) {
  textos <- Filter(function(x) !is.null(x) && !is.na(x) && nzchar(x), textos)
  if (length(textos) == 0L) return(NULL)
  if (length(textos) == 1L) {
    return(shiny::tags$p(
      class = "rodape-linha",
      shiny::tags$span(class = "rodape-rotulo", rotulo), textos[[1]]
    ))
  }
  shiny::tagList(
    shiny::tags$p(class = "rodape-linha", shiny::tags$span(class = "rodape-rotulo", rotulo)),
    shiny::tags$ul(class = "rodape-lista", lapply(textos, shiny::tags$li))
  )
}

#' Aparato de rodapé de uma aba: nota, observação e fonte, nesta ordem.
#'
#' A fonte fecha o bloco porque é a última coisa que o leitor procura; a nota
#' vem antes dela, colada ao conteúdo que qualifica.
bloco_rodape <- function(notas = NULL, observacoes = NULL, fonte = NULL) {
  linhas <- Filter(Negate(is.null), list(
    linha_rodape("Nota:", as.list(notas)),
    linha_rodape("Observação:", as.list(observacoes)),
    linha_rodape("Fonte:", as.list(fonte))
  ))
  if (length(linhas) == 0L) return(NULL)
  shiny::tags$div(class = "bloco-rodape", role = "note", linhas)
}

fonte_receita <- "Receita Federal do Brasil, tabulações por centis de declarações válidas do IRPF."

# Uma declaração não é uma pessoa. Esta frase acompanha qualquer contagem
# exibida pelo painel.
nota_unidade <- paste(
  "A unidade divulgada é a declaração válida, que pode reunir titular,",
  "dependentes e declaração conjunta; contagens de declarações não são",
  "contagens de pessoas."
)

referencia_ui <- function(bundle, chaves) {
  refs <- schema_slice(bundle, "references")
  if (is.null(refs) || length(chaves) == 0L) return(NULL)
  chaves <- unique(unlist(strsplit(stats::na.omit(chaves), ";")))
  linhas <- refs[match(chaves, refs$key), , drop = FALSE]
  linhas <- linhas[!is.na(linhas$key), , drop = FALSE]
  if (nrow(linhas) == 0L) return(NULL)
  shiny::tags$ul(
    class = "lista-referencias",
    lapply(seq_len(nrow(linhas)), function(i) {
      destino <- if (!is.na(linhas$doi[[i]])) {
        paste0("https://doi.org/", linhas$doi[[i]])
      } else if (!is.na(linhas$url[[i]])) {
        linhas$url[[i]]
      } else {
        NULL
      }
      shiny::tags$li(
        linhas$citation[[i]],
        if (!is.null(destino)) {
          shiny::tagList(
            " ",
            shiny::a(
              if (!is.na(linhas$doi[[i]])) paste0("doi:", linhas$doi[[i]]) else "Acessar",
              href = destino, target = "_blank", rel = "noopener"
            )
          )
        }
      )
    })
  )
}

#' Tabela compacta dos conceitos de renda disponíveis.
#'
#' A aba de evolução deixa trocar entre onze ordenações; sem a tabela o leitor
#' precisaria percorrer o seletor uma a uma para saber o que está comparando.
tabela_conceitos <- function(bundle, destaque = NULL) {
  rankings <- schema_slice(bundle, "rankings")
  if (is.null(rankings)) return(NULL)
  linhas <- lapply(seq_len(nrow(rankings)), function(i) {
    linha <- rankings[i, , drop = FALSE]
    anos <- if (is.na(linha$year_max[[1]])) {
      paste0(linha$year_min[[1]], "-")
    } else {
      paste0(linha$year_min[[1]], "-", linha$year_max[[1]])
    }
    shiny::tags$tr(
      class = if (identical(linha$ranking_id[[1]], destaque)) "conceito-principal" else NULL,
      shiny::tags$td(coluna_opcional(linha, "roman")),
      shiny::tags$td(linha$label[[1]]),
      shiny::tags$td(coluna_opcional(linha, "formula")),
      shiny::tags$td(anos)
    )
  })
  shiny::tags$table(
    class = "tabela-conceitos",
    shiny::tags$thead(shiny::tags$tr(
      shiny::tags$th("Tabela"), shiny::tags$th("Conceito"),
      shiny::tags$th("Composição"), shiny::tags$th("Anos")
    )),
    shiny::tags$tbody(linhas)
  )
}
