# Estado compartilhado entre as abas, link da visão atual e leitura de valores.
#
# O leitor escolhe ano e geografia numa aba e espera reencontrá-los na seguinte;
# e quer mandar a alguém "o top 1% de SP em 2023" sem descrever cliques. O
# painel guarda ano e geografia num reactiveValues comum e espelha a visão na
# URL da página.
#
# Particularidade do shinylive: o app roda num iframe cuja URL não traz a query
# da página (`/app/?geo=SP` abre o iframe em `/app/app_<hash>/`). Os dois são da
# mesma origem, então www/estado-url.js copia a query da página para o iframe
# antes de o Shiny iniciar e devolve a ela as mudanças de visão.

abas_painel <- c(
  "visao-geral", "evolucao", "topos", "rendimentos", "bens", "dividas",
  "estados", "metodologia"
)
abas_com_ano <- c("topos", "rendimentos", "bens", "dividas", "estados")
abas_com_geo <- c("evolucao", "topos", "rendimentos", "bens", "dividas")

grupos_de_campos <- c(
  "Tributáveis" = "taxable", "Exclusivos" = "exclusive", "Isentos" = "exempt",
  "Deduções" = "deduction", "Imposto" = "tax"
)

# Lê a query da URL e devolve só o que vale para este bundle. Valor
# desconhecido — link antigo, digitação — cai no padrão da aba em vez de
# quebrar a abertura.
ler_permalink <- function(busca, bundle) {
  campos <- if (is.null(busca) || !nzchar(busca)) list() else shiny::parseQueryString(busca)
  valido <- function(nome, permitidos) {
    valor <- campos[[nome]]
    if (is.null(valor) || length(valor) != 1L || !valor %in% permitidos) NULL else valor
  }
  lista <- function(nome, permitidos, maximo) {
    valor <- campos[[nome]]
    if (is.null(valor)) return(NULL)
    partes <- intersect(strsplit(valor, ",", fixed = TRUE)[[1]], permitidos)
    if (length(partes) == 0L) NULL else utils::head(partes, maximo)
  }
  geos <- unique(as.character(bundle$metrics$geo_code))
  list(
    aba = valido("aba", abas_painel),
    ano = valido("ano", as.character(unique(bundle$metrics$year))),
    geo = valido("geo", geos),
    comparar = lista("comparar", geos, 2L),
    ind = valido("ind", unname(metric_choices)),
    conceito = valido("conceito", unique(as.character(bundle$metrics$ranking_id))),
    grupo = valido("grupo", unname(grupos_de_campos)),
    sem_topo = identical(campos$sem_topo, "1"),
    ordem = valido("ordem", c("valor", "nome", "regiao"))
  )
}

# Monta a query a partir de uma lista nomeada. Os valores vêm de vocabulário
# controlado (códigos, ids de indicador), então não há o que escapar além do
# padrão de URLencode.
montar_query <- function(parametros) {
  vazio <- function(x) is.null(x) || length(x) == 0L || identical(x, FALSE) || !any(nzchar(x))
  parametros <- parametros[!vapply(parametros, vazio, logical(1))]
  if (length(parametros) == 0L) return("")
  valores <- vapply(
    parametros,
    function(x) if (isTRUE(x)) "1" else utils::URLencode(paste(x, collapse = ",")),
    character(1)
  )
  paste0("?", paste(names(valores), valores, sep = "=", collapse = "&"))
}

# Liga um filtro da aba ao estado comum, nos dois sentidos.
#
# Só a aba visível escreve no estado: as outras recebem o valor novo e se
# atualizam, e se também escrevessem devolveriam o valor antigo no meio da
# troca. A guarda `identical()` encerra o vaivém entre filtro e estado.
# `primeiro = TRUE` serve à aba Evolução, em que a geografia é uma lista e o
# estado comum acompanha a primeira.
sincronizar_estado <- function(session, input, estado, campo, input_id = campo,
                               ativo = NULL, primeiro = FALSE) {
  if (is.null(estado)) return(invisible(NULL))
  shiny::observeEvent(estado[[campo]], {
    novo <- estado[[campo]]
    atual <- input[[input_id]]
    if (primeiro) {
      if (length(atual) > 0L && identical(atual[[1]], novo)) return()
      novo <- unique(c(novo, setdiff(atual, novo)))
    } else if (identical(atual, novo)) {
      return()
    }
    shiny::updateSelectInput(session, input_id, selected = novo)
  }, ignoreInit = TRUE)
  shiny::observeEvent(input[[input_id]], {
    if (!is.null(ativo) && !isTRUE(ativo())) return()
    valor <- input[[input_id]]
    if (primeiro) valor <- valor[[1]]
    if (!identical(estado[[campo]], valor)) estado[[campo]] <- valor
  }, ignoreInit = TRUE)
  invisible(NULL)
}

# Valor inicial de um filtro: o do estado comum (que já traz o link da URL), se
# existir entre as escolhas da aba; senão, o padrão.
valor_inicial <- function(estado, campo, escolhas, padrao) {
  valor <- if (is.null(estado)) NULL else shiny::isolate(estado[[campo]])
  if (!is.null(valor) && valor %in% escolhas) valor else padrao
}

# ---------------------------------------------------------------------------
# Leitura do valor sob o cursor
# ---------------------------------------------------------------------------

# Sem pacote novo: o plotOutput já informa a posição do ponteiro em
# coordenadas dos dados. A leitura vai num uiOutput à parte, para o gráfico não
# ser redesenhado a cada movimento; no celular, o toque vale como clique.
grafico_interativo <- function(ns, id, height) {
  shiny::tagList(
    shiny::plotOutput(
      ns(id), height = height,
      hover = shiny::hoverOpts(
        ns(paste0(id, "_hover")), delay = 80, delayType = "throttle", nullOutside = TRUE
      ),
      click = shiny::clickOpts(ns(paste0(id, "_click")))
    ),
    shiny::div(
      class = "leitura-ponto", `aria-live` = "polite",
      shiny::uiOutput(ns(paste0(id, "_leitura")), inline = TRUE)
    )
  )
}

evento_ponteiro <- function(input, id) {
  input[[paste0(id, "_hover")]] %||% input[[paste0(id, "_click")]]
}

# Linhas dos dados na posição mais próxima do ponteiro no eixo x. Em eixo
# discreto — os 20 grupos do topo — o Shiny devolve a posição 1, 2, ..., e o
# nível correspondente vem de `discrete_limits`.
linhas_no_ponteiro <- function(dados, evento, coluna_x) {
  nada <- dados[0, , drop = FALSE]
  if (is.null(evento) || is.null(evento$x) || nrow(dados) == 0L) return(nada)
  niveis <- evento$domain$discrete_limits$x
  if (!is.null(niveis)) {
    i <- round(evento$x)
    if (i < 1L || i > length(niveis)) return(nada)
    return(dados[as.character(dados[[coluna_x]]) == niveis[[i]], , drop = FALSE])
  }
  x <- dados[[coluna_x]]
  if (!any(is.finite(x))) return(nada)
  alvo <- x[which.min(abs(x - evento$x))]
  dados[x == alvo, , drop = FALSE]
}

leitura_ui <- function(texto) {
  if (is.null(texto) || length(texto) == 0L || !nzchar(texto[[1]])) {
    return(shiny::span(
      class = "leitura-dica",
      "Passe o cursor ou toque no gráfico para ler os valores."
    ))
  }
  shiny::span(texto)
}

# ---------------------------------------------------------------------------
# Variação anual e ressalva de 2018
# ---------------------------------------------------------------------------

# Variação contra o ano anterior, para as caixas de valor: um número sozinho não
# diz se subiu ou desceu. Quando a comparação toca 2018, a ressalva vai junto.
variacao_ui <- function(atual, anterior, coluna, formatar, unidade, ano) {
  if (is.null(anterior) || nrow(anterior) == 0L || nrow(atual) == 0L) return(NULL)
  if (!is.finite(anterior[[coluna]]) || !is.finite(atual[[coluna]])) return(NULL)
  ano <- as.integer(ano)
  delta <- atual[[coluna]] - anterior[[coluna]]
  sinal <- if (delta > 0) "+" else if (delta < 0) "−" else "="
  ressalva <- if (ano %in% c(2018L, 2019L)) " (2018 não comparável)" else ""
  shiny::p(
    class = "small text-muted mb-0",
    paste0(sinal, formatar(abs(delta)), " ", unidade, " ante ", ano - 1L, ressalva)
  )
}

# Geografias em que 2018 destoa dos anos vizinhos no indicador escolhido. O
# salto não é só nacional — aparece com força em PE e SP — e na maioria das UFs
# o ano segue a tendência; a nota de rodapé usa isto para falar do que o
# gráfico mostra.
geografias_salto_2018 <- function(metrics, ranking, metric, geos = NULL, limiar = 0.05) {
  if (!metric %in% names(metrics)) return(character())
  d <- metrics[metrics$ranking_id == ranking & metrics$year %in% 2017:2019, , drop = FALSE]
  if (!is.null(geos)) d <- d[d$geo_code %in% geos, , drop = FALSE]
  if (nrow(d) == 0L) return(character())
  saltou <- vapply(split(d, d$geo_code), function(bloco) {
    v <- stats::setNames(bloco[[metric]], bloco$year)
    if (!all(c("2017", "2018", "2019") %in% names(v))) return(FALSE)
    referencia <- mean(v[c("2017", "2019")])
    all(is.finite(c(v[["2018"]], referencia))) && referencia != 0 &&
      abs(v[["2018"]] - referencia) / abs(referencia) > limiar
  }, logical(1))
  names(saltou)[saltou]
}
