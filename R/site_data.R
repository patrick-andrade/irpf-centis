# Contrato de dados das páginas Explorar e das figuras dos relatórios.
#
# As páginas rodam no navegador (Quarto + OJS) e as figuras dos PDFs são
# desenhadas pelo mesmo módulo JavaScript no Node. Os dois leem os JSON
# escritos aqui. A regra da divisão de trabalho: tudo o que é cálculo,
# julgamento analítico ou texto com número (médias por declaração, totais com
# campo ausente, saltos de 2018, cartões da visão geral) sai pronto e testado
# em R; o JavaScript filtra, formata e desenha.
#
# Formato: JSON colunar ({"coluna": [valores]}), com LF, sem carimbo de hora
# (o arquivo só muda quando o dado muda) e com `schema_version`. Precisão:
# inteiros exatos, valores monetários ao real, proporções, alíquotas e índices
# com seis casas; NA, NaN e infinitos viram `null`.

versao_esquema_site <- 1L

grupos_de_campos_site <- c(
  "Tributáveis" = "taxable", "Exclusivos" = "exclusive", "Isentos" = "exempt",
  "Deduções" = "deduction", "Imposto" = "tax"
)

componentes_bens <- c("assets_real_estate", "assets_movable", "assets_financial", "assets_other")

colunas_inteiras <- c("year", "bin_code", "contributors", "joint_returns", "dependents")
colunas_monetarias <- c(
  "value_real", "value_nominal", "assets_sum_real", "debts_real", "rank_sum_real",
  "income_total_real", "income_mean_real", "income_total", "income_mean",
  "patrimonio_medio", "divida_media"
)

# Chave de ordenação sem acentos: na colação C, "Paraíba" viria depois de
# "Paraná" e de "Pernambuco".
sem_acento <- function(x) {
  tolower(chartr(
    "áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ",
    "aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC",
    x
  ))
}

# Brasil primeiro, UFs pelo nome, Exterior por último: a mesma ordem em todos
# os seletores.
ordenar_geografias <- function(geografias, codigos = geografias$geo_code) {
  g <- geografias[geografias$geo_code %in% codigos, , drop = FALSE]
  nivel <- ifelse(g$geo_code == "BR", 0L, ifelse(g$geo_code == "EX", 2L, 1L))
  g[order(nivel, sem_acento(g$geo_name)), , drop = FALSE]
}

# Geografias em que 2018 destoa dos anos vizinhos no indicador escolhido: o
# valor de 2018 se afasta mais de 5% da média de 2017 e 2019. O salto não é só
# nacional (aparece com força em PE e SP), e as notas das páginas falam do que
# o gráfico mostra a partir desta lista.
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

# Totais por componente sem transformar ausência em zero: só NA continua NA.
component_totals <- function(data) {
  data |>
    dplyr::group_by(.data$component_id, .data$field_label) |>
    dplyr::summarise(value = sum_known_values(.data$value_real), .groups = "drop")
}

indicadores_do_seletor <- function(indicadores = read_schema("indicators")) {
  sel <- indicadores[!is.na(indicadores$explorar_ordem), , drop = FALSE]
  sel <- sel[order(sel$explorar_ordem), , drop = FALSE]
  tibble::tibble(id = sel$indicator_id, rotulo = sel$label)
}

arredondar_site <- function(df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  for (coluna in names(df)) {
    x <- df[[coluna]]
    if (is.factor(x)) {
      df[[coluna]] <- as.character(x)
    } else if (is.numeric(x)) {
      x[!is.finite(x)] <- NA
      df[[coluna]] <- if (coluna %in% colunas_inteiras) {
        as.integer(round(x))
      } else if (coluna %in% colunas_monetarias) {
        round(x, 0)
      } else {
        round(x, 6)
      }
    }
  }
  df
}

# Tabela em formato colunar. `I()` impede que o auto_unbox do jsonlite
# transforme uma coluna de um valor só num escalar: o JavaScript espera listas.
colunar <- function(df) {
  df <- arredondar_site(df)
  stats::setNames(lapply(names(df), function(n) I(df[[n]])), names(df))
}

# Escreve JSON em UTF-8 com LF, por conexão binária: no Windows uma conexão de
# texto trocaria o fim de linha, e o arquivo gerado aqui e no CI precisa ser o
# mesmo byte a byte.
escrever_json_site <- function(objeto, caminho) {
  fs::dir_create(fs::path_dir(caminho), recurse = TRUE)
  texto <- jsonlite::toJSON(
    objeto, dataframe = "columns", na = "null", null = "null",
    digits = NA, auto_unbox = TRUE
  )
  con <- file(caminho, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(enc2utf8(paste0(texto, "\n"))), con)
  caminho
}

escrever_csv_completo <- function(dados, caminho) {
  fs::dir_create(fs::path_dir(caminho), recurse = TRUE)
  linhas <- utils::capture.output(utils::write.csv(as.data.frame(dados), row.names = FALSE, na = ""))
  con <- file(caminho, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(enc2utf8(paste0(paste(linhas, collapse = "\n"), "\n"))), con)
  caminho
}

# Componentes de renda e patrimônio por grupo, como o painel usava: RB4, só as
# folhas disjuntas, soma por campo preservando a ausência.
componentes_agregados <- function(income_components) {
  income_components |>
    dplyr::filter(
      .data$ranking_id == "RB4",
      .data$bin_code %in% c(1:99, 101:109, 111:120)
    ) |>
    dplyr::group_by(
      .data$year, .data$geo_code, .data$component_id, .data$component_group, .data$field_label
    ) |>
    dplyr::summarise(value_real = sum_known_values(.data$value_real), .groups = "drop")
}

saltos_2018_por_conceito <- function(metrics, indicadores, geos = NULL) {
  conceitos <- unique(as.character(metrics$ranking_id))
  stats::setNames(lapply(conceitos, function(conceito) {
    stats::setNames(
      lapply(indicadores, function(ind) I(geografias_salto_2018(metrics, conceito, ind, geos))),
      indicadores
    )
  }), conceitos)
}

# Malha das UFs em GeoJSON com os anéis na orientação que o d3-geo espera:
# exterior em sentido horário, buracos em sentido anti-horário (em
# longitude/latitude). Na orientação contrária, o d3 lê o polígono como "o
# globo inteiro menos a UF" e pinta o mapa todo.
area_assinada <- function(x, y) {
  n <- length(x)
  if (n < 3L) return(0)
  j <- c(seq.int(2L, n), 1L)
  sum(x * y[j] - x[j] * y) / 2
}

malha_ufs_geojson <- function(state_polygons, geografias, casas = 4L) {
  partes <- strsplit(state_polygons$piece, "-", fixed = TRUE)
  poligono <- vapply(partes, function(p) paste(p[1:2], collapse = "-"), character(1))
  anel <- vapply(partes, function(p) as.integer(p[[3]]), integer(1))
  uf_por_codarea <- stats::setNames(geografias$geo_code, as.character(geografias$ibge_code))
  nome_por_uf <- stats::setNames(geografias$geo_name, geografias$geo_code)
  feicoes <- lapply(unique(state_polygons$codarea), function(codarea) {
    linhas <- which(state_polygons$codarea == codarea)
    poligonos <- unique(poligono[linhas])
    coordenadas <- lapply(poligonos, function(p) {
      idx <- linhas[poligono[linhas] == p]
      lapply(sort(unique(anel[idx])), function(a) {
        i <- idx[anel[idx] == a]
        x <- round(state_polygons$long[i], casas)
        y <- round(state_polygons$lat[i], casas)
        exterior <- a == 1L
        area <- area_assinada(x, y)
        if ((exterior && area > 0) || (!exterior && area < 0)) {
          x <- rev(x)
          y <- rev(y)
        }
        unname(cbind(x, y))
      })
    })
    uf <- unname(uf_por_codarea[as.character(codarea)])
    list(
      type = "Feature",
      properties = list(uf = uf, nome = unname(nome_por_uf[uf]), codarea = as.character(codarea)),
      geometry = list(type = "MultiPolygon", coordinates = coordenadas)
    )
  })
  list(type = "FeatureCollection", features = feicoes)
}

escrever_geojson <- function(objeto, caminho) {
  fs::dir_create(fs::path_dir(caminho), recurse = TRUE)
  texto <- jsonlite::toJSON(objeto, auto_unbox = TRUE, digits = NA)
  con <- file(caminho, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(enc2utf8(paste0(texto, "\n"))), con)
  caminho
}

# Variação contra o ano anterior para as caixas de valor: "+0,006 ponto ante
# 2023". Quando a comparação toca 2018, a ressalva vai junto.
texto_variacao <- function(atual, anterior, formatar, unidade, ano) {
  if (!is.finite(atual) || !is.finite(anterior)) return(NA_character_)
  delta <- atual - anterior
  sinal <- if (delta > 0) "+" else if (delta < 0) "−" else "="
  ressalva <- if (as.integer(ano) %in% c(2018L, 2019L)) " (2018 não comparável)" else ""
  paste0(sinal, formatar(abs(delta)), " ", unidade, " ante ", as.integer(ano) - 1L, ressalva)
}

# Visão geral: as quatro caixas e os cartões de pergunta, já redigidos. Cada
# cartão faz a pergunta que o leitor traria, responde com um número do estudo
# e leva à página que aprofunda a resposta.
visao_geral_site <- function(metrics, effective_tax, wealth_bins, geografias) {
  ultimo <- max(metrics$year)
  primeiro <- min(metrics$year)
  br <- metrics[metrics$geo_code == "BR" & metrics$ranking_id == "RB4", , drop = FALSE]
  linha <- function(ano) br[br$year == ano, , drop = FALSE]
  pct <- function(x) fmt_share(x, 0.1)
  ind <- function(x) fmt_index(x, 0.001)
  pontos <- function(x) fmt_index(x, 0.001)
  pp <- function(x) fmt_index(100 * x, 0.1)
  nome <- function(codigo) geografias$geo_name[match(codigo, geografias$geo_code)]

  atual <- linha(ultimo)
  anterior <- linha(ultimo - 1L)
  valor_anterior <- function(coluna) if (nrow(anterior) == 1L) anterior[[coluna]] else NA_real_
  caixas <- list(
    list(id = "contributors", titulo = paste("Declarantes —", ultimo), valor = fmt_count(atual$contributors),
         variacao = texto_variacao(atual$contributors, valor_anterior("contributors"), fmt_count, "declarações", ultimo)),
    list(id = "gini_grouped", titulo = "Gini agrupado", valor = ind(atual$gini_grouped),
         variacao = texto_variacao(atual$gini_grouped, valor_anterior("gini_grouped"), pontos, "ponto", ultimo)),
    list(id = "top_1_share", titulo = "Participação do top 1%", valor = pct(atual$top_1_share),
         variacao = texto_variacao(atual$top_1_share, valor_anterior("top_1_share"), pp, "p.p.", ultimo)),
    list(id = "top_0_1_share", titulo = "Participação do top 0,1%", valor = pct(atual$top_0_1_share),
         variacao = texto_variacao(atual$top_0_1_share, valor_anterior("top_0_1_share"), pp, "p.p.", ultimo))
  )

  perguntas <- list()
  if (nrow(linha(ultimo)) == 1L) {
    perguntas[[length(perguntas) + 1L]] <- list(
      chave = "topos", pagina = "topos", rotulo = "Topos da renda",
      pergunta = "Quanto da renda declarada fica com o 1% do topo?",
      resposta = paste0(
        "Em ", ultimo, ", o 1% de maior renda declarou ", pct(linha(ultimo)$top_1_share),
        " da renda RB4; o 0,1%, ", pct(linha(ultimo)$top_0_1_share), "."
      )
    )
  }
  if (nrow(linha(primeiro)) == 1L && nrow(linha(ultimo)) == 1L) {
    perguntas[[length(perguntas) + 1L]] <- list(
      chave = "evolucao", pagina = "evolucao", rotulo = "Evolução",
      pergunta = "A desigualdade entre declarantes aumentou?",
      resposta = paste0(
        "O Gini agrupado foi de ", ind(linha(primeiro)$gini_grouped), " em ", primeiro,
        " a ", ind(linha(ultimo)$gini_grouped), " em ", ultimo, ". O ano de 2018 não é comparável."
      )
    )
  }
  a <- effective_tax[effective_tax$ranking_id == "RB4" & effective_tax$geo_code == "BR", , drop = FALSE]
  a <- a[a$year == max(a$year) & is.finite(a$effective_rate), , drop = FALSE]
  topo_aliquota <- a[a$bin_code == max(a$bin_code), , drop = FALSE]
  if (nrow(a) > 0L && nrow(topo_aliquota) == 1L) {
    perguntas[[length(perguntas) + 1L]] <- list(
      chave = "rendimentos", pagina = "rendimentos", rotulo = "Rendimentos e imposto",
      pergunta = "Quem paga mais imposto, em proporção da renda?",
      resposta = paste0(
        "Em ", max(a$year), ", a alíquota efetiva média chega a ", pct(max(a$effective_rate)),
        " no grupo de maior carga e fica em ", pct(topo_aliquota$effective_rate),
        " no 0,01% de maior renda."
      )
    )
  }
  estados <- metrics[metrics$year == ultimo & metrics$geo_level == "state" &
    metrics$ranking_id == "RB4" & is.finite(metrics$gini_grouped), , drop = FALSE]
  if (nrow(estados) >= 2L) {
    menor <- estados[which.min(estados$gini_grouped), ]
    maior <- estados[which.max(estados$gini_grouped), ]
    perguntas[[length(perguntas) + 1L]] <- list(
      chave = "estados", pagina = "estados", rotulo = "Estados e regiões",
      pergunta = "Como a desigualdade varia entre os estados?",
      resposta = paste0(
        "Em ", ultimo, ", o Gini agrupado vai de ", ind(menor$gini_grouped), " (",
        nome(menor$geo_code), ") a ", ind(maior$gini_grouped), " (",
        nome(maior$geo_code), "), com centis calculados dentro de cada UF."
      )
    )
  }
  p <- wealth_bins[wealth_bins$geo_code == "BR", , drop = FALSE]
  if (nrow(p) > 0L) {
    p <- p[p$year == max(p$year), , drop = FALSE]
    topo <- p[p$share_lower >= 0.99 - 1e-9, , drop = FALSE]
    if (nrow(topo) > 0L && any(is.finite(topo$assets_share))) {
      perguntas[[length(perguntas) + 1L]] <- list(
        chave = "bens", pagina = "bens", rotulo = "Bens",
        pergunta = "Quanto patrimônio declara quem está no topo da renda?",
        resposta = paste0(
          "Em ", max(p$year), ", o 1% de maior renda declarou ",
          pct(sum(topo$assets_share, na.rm = TRUE)), " dos bens e direitos."
        )
      )
    }
  }
  list(
    schema_version = versao_esquema_site,
    ano = ultimo,
    caixas = caixas,
    perguntas = perguntas,
    observacao = paste0(
      "Os cartões acima trazem o Brasil no conceito central de renda (RB4), ",
      "no ano-calendário ", ultimo, ", com a variação contra o ano anterior."
    )
  )
}

# Escreve todos os JSON das páginas Explorar e os CSV completos da página de
# dados. Devolve os caminhos, para o target de formato "file".
write_site_data <- function(income_components, metrics, effective_tax, wealth_bins, top_counts,
                            wealth_metrics, metrics_sem_topo, state_polygons, state_labels,
                            destino = project_path("explorar", "dados")) {
  geografias <- read_schema("geographies")
  rankings <- read_schema("rankings")
  indicadores <- read_schema("indicators")
  referencias <- read_schema("references")
  seletor <- indicadores_do_seletor(indicadores)
  caminhos <- character()
  escrever <- function(objeto, ...) {
    caminho <- fs::path(destino, ...)
    caminhos <<- c(caminhos, escrever_json_site(objeto, caminho))
  }
  anos <- sort(unique(as.integer(metrics$year)))
  geos_metricas <- ordenar_geografias(geografias, unique(metrics$geo_code))

  componentes <- componentes_agregados(income_components)
  campos <- unique(componentes[, c("component_id", "component_group", "field_label")])
  campos <- campos[order(campos$component_group, campos$component_id), , drop = FALSE]

  escrever(list(
    schema_version = versao_esquema_site,
    safra = list(
      anos_renda = range(anos),
      anos_patrimonio_direto = range(as.integer(wealth_metrics$year)),
      ano_base_precos = 2024L
    ),
    anos = anos,
    geografias = colunar(geos_metricas[, c("geo_code", "geo_name", "geo_level", "region_name", "ibge_code")]),
    conceitos_disponiveis = unique(as.character(metrics$ranking_id)),
    indicadores_seletor = colunar(seletor),
    grupos_de_campos = colunar(tibble::tibble(id = unname(grupos_de_campos_site), rotulo = names(grupos_de_campos_site))),
    campos = colunar(campos)
  ), "comum.json")

  escrever(list(
    schema_version = versao_esquema_site,
    indicadores = colunar(indicadores),
    conceitos = colunar(rankings),
    referencias = colunar(referencias)
  ), "glossario.json")

  colunas_evolucao <- c("year", "geo_code", "ranking_id", "gini_lower_bound", "gini_upper_bound", seletor$id)
  escrever(list(
    schema_version = versao_esquema_site,
    metricas = colunar(metrics[, intersect(colunas_evolucao, names(metrics))]),
    sem_topo = colunar(metrics_sem_topo[, intersect(colunas_evolucao, names(metrics_sem_topo))]),
    saltos_2018 = saltos_2018_por_conceito(metrics, seletor$id)
  ), "evolucao.json")

  rb4 <- metrics[metrics$ranking_id == "RB4", , drop = FALSE]
  escrever(list(
    schema_version = versao_esquema_site,
    metricas = colunar(rb4[, c("year", "geo_code", "top_10_share", "top_1_share", "top_0_1_share", "top_0_01_share")]),
    contagens = colunar(top_counts[, c("year", "geo_code", "group_label", "share_lower", "contributors", "joint_returns", "dependents")])
  ), "topos.json")

  ufs <- geografias$geo_code[geografias$geo_level == "state"]
  estaduais <- rb4[rb4$geo_level == "state", c("year", "geo_code", "contributors", seletor$id), drop = FALSE]
  rotulos <- tibble::tibble(
    uf = geografias$geo_code[match(as.character(state_labels$codarea), as.character(geografias$ibge_code))],
    long = round(state_labels$long, 4), lat = round(state_labels$lat, 4)
  )
  escrever(list(
    schema_version = versao_esquema_site,
    metricas = colunar(estaduais),
    rotulos = colunar(rotulos[!is.na(rotulos$uf), , drop = FALSE]),
    saltos_2018 = saltos_2018_por_conceito(rb4, seletor$id, geos = ufs)[["RB4"]]
  ), "estados.json")
  caminhos <- c(caminhos, escrever_geojson(
    malha_ufs_geojson(state_polygons, geografias), fs::path(destino, "ufs.geojson")
  ))

  aliquotas <- effective_tax[effective_tax$ranking_id == "RB4", , drop = FALSE]
  patrimonio <- wealth_bins |>
    dplyr::mutate(
      patrimonio_medio = dplyr::if_else(.data$contributors > 0, .data$assets_sum_real / .data$contributors, NA_real_),
      divida_media = dplyr::if_else(.data$contributors > 0, .data$debts_real / .data$contributors, NA_real_)
    )
  for (geo in unique(componentes$geo_code)) {
    comp <- componentes[componentes$geo_code == geo, , drop = FALSE]
    escrever(list(
      schema_version = versao_esquema_site,
      componentes = colunar(comp[comp$component_group != "asset", c("year", "component_id", "value_real")]),
      aliquota = colunar(aliquotas[aliquotas$geo_code == geo, c("year", "bin_code", "share_upper", "effective_rate")])
    ), "rendimentos", paste0(geo, ".json"))
  }
  for (geo in unique(patrimonio$geo_code)) {
    comp <- componentes[componentes$geo_code == geo & componentes$component_id %in% componentes_bens, , drop = FALSE]
    escrever(list(
      schema_version = versao_esquema_site,
      grupos = colunar(patrimonio[patrimonio$geo_code == geo, c(
        "year", "bin_code", "share_lower", "share_upper", "contributors", "rank_sum_real",
        "assets_sum_real", "assets_share", "debts_real", "debt_share", "debt_income_ratio",
        "patrimonio_medio", "divida_media"
      )]),
      bens_componentes = colunar(comp[, c("year", "component_id", "value_real")])
    ), "patrimonio", paste0(geo, ".json"))
  }
  escrever(list(
    schema_version = versao_esquema_site,
    gini_direto = colunar(wealth_metrics[order(wealth_metrics$year), c("year", "gini_grouped")])
  ), "patrimonio-direto.json")

  escrever(visao_geral_site(metrics, effective_tax[effective_tax$ranking_id == "RB4", , drop = FALSE], wealth_bins, geografias), "visao-geral.json")

  esquema <- dplyr::bind_rows(
    dplyr::transmute(rankings, tipo = "conceito_de_renda", id = .data$ranking_id, rotulo = .data$label, definicao = .data$definition),
    dplyr::transmute(indicadores, tipo = "indicador", id = .data$indicator_id, rotulo = .data$label, definicao = .data$definition)
  )
  csv <- fs::path(destino, "csv")
  caminhos <- c(
    caminhos,
    escrever_csv_completo(metrics, fs::path(csv, "irpf-centis-indicadores.csv")),
    escrever_csv_completo(
      wealth_bins[, c("year", "geo_code", "bin_code", "share_lower", "share_upper", "contributors",
                      "rank_sum_real", "assets_sum_real", "assets_share", "debts_real", "debt_share",
                      "debt_income_ratio")],
      fs::path(csv, "irpf-centis-bens-e-dividas-por-grupo.csv")
    ),
    escrever_csv_completo(top_counts, fs::path(csv, "irpf-centis-contagens-do-topo.csv")),
    escrever_csv_completo(esquema, fs::path(csv, "irpf-centis-conceitos-e-indicadores.csv"))
  )
  unname(caminhos)
}

# Dados das figuras dos relatórios que não estão nos JSON do site: a alíquota
# efetiva por grupo agregado (todos, top 10%, top 1%, top 0,1%), Brasil, RB4.
write_report_figure_data <- function(effective_tax, destino = project_path("reports", "dados")) {
  resumo <- effective_tax_summary(effective_tax)
  resumo <- resumo[resumo$geo_code == "BR" & resumo$ranking_id == "RB4", c("year", "group", "effective_rate"), drop = FALSE]
  resumo <- resumo[order(resumo$group, resumo$year), , drop = FALSE]
  escrever_json_site(
    list(schema_version = versao_esquema_site, aliquota_grupos = colunar(resumo)),
    fs::path(destino, "aliquota-grupos.json")
  )
}

# Casos de formatação que o R (tabelas e textos dos relatórios) e o JavaScript
# (gráficos e páginas) precisam escrever igual. O arquivo
# tests/fixtures/formatos-ptbr.json é gerado daqui; test-site-data.R confere
# que ele está em dia e tests/js/fixtures.test.mjs confere o JavaScript contra
# ele. Assim, o número no texto e o número no gráfico não divergem.
fixtures_formatos <- function() {
  indice <- c(0.6039, 0.5771, 0.88, 0.1234, 1234.5678)
  participacao <- c(0.2507, 0.0742, 0.483, 0.13, 1)
  contagens <- c(41676499, 1006000, 4000, 0)
  dinheiro <- c(0, 1500, 2.5e6, 1.2e9, 3e12, 154061, 450, -2.5e6)
  percentis <- list(c(0.99, 0.9991, 1), c(0.5, 0.9))
  list(
    indice_0_001 = list(entrada = indice, saida = fmt_index(indice, 0.001)),
    indice_0_01 = list(entrada = indice, saida = fmt_index(indice, 0.01)),
    percentual_0_1 = list(entrada = participacao, saida = fmt_share(participacao, 0.1)),
    contagem = list(entrada = contagens, saida = fmt_count(contagens)),
    dinheiro = list(entrada = dinheiro, saida = rotulo_dinheiro_ptbr()(dinheiro)),
    percentil = lapply(percentis, function(p) list(entrada = p, saida = formatar_percentil(p)))
  )
}

escrever_fixtures_formatos <- function(caminho = project_path("tests", "fixtures", "formatos-ptbr.json")) {
  fs::dir_create(fs::path_dir(caminho), recurse = TRUE)
  texto <- jsonlite::toJSON(fixtures_formatos(), digits = NA, auto_unbox = FALSE, pretty = TRUE)
  con <- file(caminho, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(enc2utf8(paste0(texto, "\n"))), con)
  caminho
}
