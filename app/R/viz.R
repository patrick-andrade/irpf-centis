# GERADO AUTOMATICAMENTE — não edite este arquivo.
# Cópia de R/viz.R, sincronizada por sync_app_viz().

# Camada de visualização compartilhada entre os relatórios e o painel.
#
# Por que ela existe: cada gráfico do projeto definia cor, escala e tema por
# conta própria. O mesmo âmbar era "RB3" num gráfico e "ponto de destaque" em
# outro, e nenhuma escala declarava domínio — o ggplot ajustava ao dado, de modo
# que 0,03 de variação no Gini patrimonial ocupava a altura inteira do painel e
# 16 anos estáveis viravam um penhasco.
#
# A regra adotada aqui segue Correll, Bertini & Franconeri (CHI 2020): indicar
# o truncamento não desfaz o exagero percebido, então a faixa precisa ser
# escolhida a partir do domínio e declarada, com âncoras redondas. Onde a
# codificação é comprimento (barras), o zero não é negociável.
#
# Restrição de ambiente: este arquivo roda no navegador via shinylive/WebAssembly.
# Usar apenas ggplot2, scales, viridisLite, grDevices e stats — todos já
# confirmados em repo.r-wasm.org. Pacote novo exige checar a disponibilidade
# wasm antes de entrar no DESCRIPTION.

cores_irpf <- list(
  tinta = "#1A1A1A",
  texto_suave = "#5B6770",
  grade = "#DDE2E6",
  referencia = "#8A9199",
  contexto = "#B0B7BD",
  fundo = "#FFFFFF"
)

# ---------------------------------------------------------------------------
# Tema
# ---------------------------------------------------------------------------

# `direcao` diz em qual eixo a grade ajuda a comparar: "y" para séries no tempo
# e curvas, "x" para barras horizontais. A grade no eixo das categorias não
# serve à leitura e compete com a tinta dos dados.
tema_irpf <- function(base_size = 12, direcao = c("y", "x", "ambos", "nenhum")) {
  direcao <- match.arg(direcao)
  linha_grade <- ggplot2::element_line(colour = cores_irpf$grade, linewidth = 0.35)
  vazio <- ggplot2::element_blank()

  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      # Grades menores somam ruído sem ajudar a ler valor algum.
      panel.grid.minor = vazio,
      panel.grid.major.y = if (direcao %in% c("y", "ambos")) linha_grade else vazio,
      panel.grid.major.x = if (direcao %in% c("x", "ambos")) linha_grade else vazio,
      panel.background = ggplot2::element_rect(fill = cores_irpf$fundo, colour = NA),
      # O site oferece tema escuro; sem fundo explícito a figura fica
      # transparente e o texto escuro some sobre o fundo do tema.
      plot.background = ggplot2::element_rect(fill = cores_irpf$fundo, colour = NA),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      plot.title = ggplot2::element_text(
        size = base_size * 1.2, face = "bold", colour = cores_irpf$tinta,
        hjust = 0, margin = ggplot2::margin(b = 4)
      ),
      plot.subtitle = ggplot2::element_text(
        size = base_size * 0.92, colour = cores_irpf$texto_suave,
        hjust = 0, margin = ggplot2::margin(b = 12)
      ),
      plot.caption = ggplot2::element_text(
        size = base_size * 0.78, colour = cores_irpf$texto_suave,
        hjust = 0, margin = ggplot2::margin(t = 10)
      ),
      axis.title = ggplot2::element_text(size = base_size * 0.88, colour = cores_irpf$texto_suave),
      axis.text = ggplot2::element_text(size = base_size * 0.85, colour = cores_irpf$texto_suave),
      axis.ticks = vazio,
      legend.position = "top",
      legend.justification = "left",
      legend.margin = ggplot2::margin(b = 4),
      legend.key.height = grid::unit(base_size * 0.9, "pt"),
      legend.text = ggplot2::element_text(size = base_size * 0.85, colour = cores_irpf$tinta),
      legend.title = ggplot2::element_text(size = base_size * 0.85, colour = cores_irpf$texto_suave),
      plot.margin = ggplot2::margin(10, 14, 8, 8)
    )
}

# ggplot não quebra título nem subtítulo: texto mais largo que a figura é
# simplesmente cortado, e o leitor perde o fim da frase sem perceber. A quebra
# é feita no texto, antes de entrar no gráfico.
quebrar_texto <- function(x, largura) {
  if (is.null(x) || length(x) == 0L || is.na(x[1]) || !nzchar(x[1])) return(x)
  paste(strwrap(x, width = largura), collapse = "\n")
}

# Larguras calibradas para as proporções usadas nos relatórios e no painel: o
# título é maior e em negrito, então cabe menos texto que no subtítulo.
rotulos_irpf <- function(titulo = NULL, subtitulo = NULL, caption = NULL) {
  ggplot2::labs(
    title = quebrar_texto(titulo, 68),
    subtitle = quebrar_texto(subtitulo, 88),
    caption = quebrar_texto(caption, 104)
  )
}

linha_zero <- function(direcao = c("h", "v")) {
  direcao <- match.arg(direcao)
  args <- list(colour = cores_irpf$referencia, linewidth = 0.4)
  if (direcao == "h") {
    do.call(ggplot2::geom_hline, c(list(yintercept = 0), args))
  } else {
    do.call(ggplot2::geom_vline, c(list(xintercept = 0), args))
  }
}

# ---------------------------------------------------------------------------
# Domínios e quebras
# ---------------------------------------------------------------------------

# Escolhe um passo redondo. Correll et al. mediram erro de leitura maior quando
# a âncora do eixo não é redonda (eixos começando em 25%), então as quebras
# saem sempre de uma escada 1-2-5.
passo_bonito <- function(amplitude, alvo = 5) {
  if (!is.finite(amplitude) || amplitude <= 0) return(1)
  bruto <- amplitude / max(alvo, 1)
  magnitude <- 10^floor(log10(bruto))
  candidatos <- c(1, 2, 2.5, 5, 10) * magnitude
  candidatos[which.min(abs(candidatos - bruto))]
}

# Devolve c(min, max) arredondado para fora, com amplitude mínima garantida.
# `span_min` é o que impede uma variação minúscula de ocupar o painel inteiro.
dominio_ancorado <- function(valores, span_min = 0, ancora = NULL,
                             incluir_zero = FALSE, teto = NULL, passo = NULL) {
  if (!is.null(ancora)) return(sort(ancora[1:2]))
  finitos <- valores[is.finite(valores)]
  if (length(finitos) == 0L) return(c(0, 1))

  baixo <- min(finitos)
  alto <- max(finitos)
  if (incluir_zero) baixo <- min(0, baixo)
  if (alto == baixo) alto <- baixo + max(span_min, abs(baixo) * 0.1, 1e-6)

  # Amplitude mínima: expande em torno do centro dos dados, não do zero.
  if ((alto - baixo) < span_min) {
    centro <- (alto + baixo) / 2
    baixo <- centro - span_min / 2
    alto <- centro + span_min / 2
    if (incluir_zero) baixo <- min(0, baixo)
  }

  if (is.null(passo)) passo <- passo_bonito(alto - baixo)
  baixo <- floor(baixo / passo) * passo
  alto <- ceiling(alto / passo) * passo
  if (incluir_zero) baixo <- min(0, baixo)
  if (!is.null(teto)) alto <- min(alto, teto)
  c(baixo, alto)
}

quebras_do_dominio <- function(dominio, passo = NULL) {
  if (is.null(passo)) passo <- passo_bonito(diff(dominio))
  seq(dominio[1], dominio[2], by = passo)
}

# ---------------------------------------------------------------------------
# Rótulos em português
# ---------------------------------------------------------------------------

rotulo_indice <- function(accuracy = 0.01) {
  scales::label_number(accuracy = accuracy, big.mark = ".", decimal.mark = ",")
}

rotulo_percentual <- function(accuracy = 0.1) {
  scales::label_percent(accuracy = accuracy, big.mark = ".", decimal.mark = ",")
}

# `scales::cut_short_scale()` emite sufixos do inglês — "R$ 500B" lido em
# português não é quinhentos bilhões. Esta função usa a escala curta em
# português: mil, mi, bi, tri.
rotulo_dinheiro_ptbr <- function(accuracy = 0.1, prefixo = "R$ ") {
  function(x) {
    formatar_um <- function(valor) {
      if (is.na(valor)) return(NA_character_)
      if (valor == 0) return(paste0(prefixo, "0"))
      magnitude <- abs(valor)
      corte <- c(1e12, 1e9, 1e6, 1e3, 1)
      sufixo <- c(" tri", " bi", " mi", " mil", "")
      i <- which(magnitude >= corte)[1]
      if (is.na(i)) i <- length(corte)
      escalado <- valor / corte[i]
      precisao <- if (sufixo[i] == "") 1 else accuracy
      paste0(
        prefixo,
        scales::number(escalado, accuracy = precisao, big.mark = ".", decimal.mark = ","),
        sufixo[i]
      )
    }
    vapply(x, formatar_um, character(1), USE.NAMES = FALSE)
  }
}

rotulo_contagem <- function() {
  scales::label_number(accuracy = 1, big.mark = ".", decimal.mark = ",")
}

# ---------------------------------------------------------------------------
# Escalas com domínio declarado
# ---------------------------------------------------------------------------

# Índices limitados (Gini, Atkinson, Theil normalizado). `span_min` de 0,15 é o
# padrão para Gini de renda: cobre a distância entre RTB (~0,50) e RB5 sem
# deixar uma variação de 0,03 preencher o painel.
escala_indice <- function(valores, span_min = 0.15, ancora = NULL,
                          eixo = c("y", "x"), nome = ggplot2::waiver(),
                          accuracy = 0.01) {
  eixo <- match.arg(eixo)
  dominio <- dominio_ancorado(valores, span_min = span_min, ancora = ancora)
  passo <- passo_bonito(diff(dominio))
  escala <- if (eixo == "y") ggplot2::scale_y_continuous else ggplot2::scale_x_continuous
  escala(
    name = nome,
    limits = dominio,
    breaks = quebras_do_dominio(dominio, passo),
    labels = rotulo_indice(accuracy),
    expand = ggplot2::expansion(mult = 0.01)
  )
}

# Participações e alíquotas: o zero entra sempre. Onde a codificação é
# comprimento (barras) isso não é negociável, e mesmo em linhas a leitura
# "quanto do total" só faz sentido a partir de zero.
escala_participacao <- function(valores, eixo = c("y", "x"), ancora = NULL,
                                nome = ggplot2::waiver(), accuracy = 0.1) {
  eixo <- match.arg(eixo)
  dominio <- dominio_ancorado(valores, ancora = ancora, incluir_zero = TRUE, teto = 1)
  escala <- if (eixo == "y") ggplot2::scale_y_continuous else ggplot2::scale_x_continuous
  escala(
    name = nome,
    limits = dominio,
    breaks = quebras_do_dominio(dominio),
    labels = rotulo_percentual(accuracy),
    expand = ggplot2::expansion(mult = c(0, 0.02))
  )
}

escala_aliquota <- function(valores, eixo = c("y", "x"), nome = ggplot2::waiver(),
                            accuracy = 0.1) {
  escala_participacao(valores, eixo = eixo, nome = nome, accuracy = accuracy)
}

escala_dinheiro <- function(valores, eixo = c("x", "y"), nome = ggplot2::waiver(),
                            incluir_zero = TRUE) {
  eixo <- match.arg(eixo)
  dominio <- dominio_ancorado(valores, incluir_zero = incluir_zero)
  escala <- if (eixo == "y") ggplot2::scale_y_continuous else ggplot2::scale_x_continuous
  escala(
    name = nome,
    limits = dominio,
    breaks = quebras_do_dominio(dominio),
    labels = rotulo_dinheiro_ptbr(),
    expand = ggplot2::expansion(mult = c(0, 0.02))
  )
}

# Grupos disjuntos do topo: o centil 99 como entrada, os dez décimos do top 1%
# e os dez décimos do top 0,1%. Em eixo linear de percentil esses 20 grupos
# ocupam 2% da largura e viram um penhasco ilegível — que é exatamente onde
# está o achado principal do estudo. Em eixo ordinal, cada um ganha a mesma
# largura e a queda da alíquota no topo fica visível.
codigos_topo <- c(99L, 101:109, 111:120)

# Precisão uniforme dentro do mesmo eixo: alternar entre uma e duas casas faz a
# sequência "99,8 / 99,90 / 99,91" parecer um retrocesso e trava a leitura.
formatar_percentil <- function(x, accuracy = NULL) {
  if (is.null(accuracy)) accuracy <- if (any(x >= 0.999, na.rm = TRUE)) 0.01 else 0.1
  scales::number(100 * x, accuracy = accuracy, decimal.mark = ",", big.mark = ".")
}

# Converte o limite superior de cada grupo do topo num fator ordenado, para que
# o eixo trate os 20 grupos como categorias de largura igual.
eixo_ordinal_topo <- function(share_upper) {
  factor(
    formatar_percentil(share_upper),
    levels = formatar_percentil(sort(unique(share_upper)))
  )
}

# Todo ano rotulado, sem folga proporcional: os extremos do eixo ficam legíveis
# em vez de sobrar 5% de margem sem marca nenhuma.
escala_ano <- function(anos, nome = NULL) {
  anos <- sort(unique(anos[is.finite(anos)]))
  ggplot2::scale_x_continuous(
    name = nome,
    breaks = anos,
    expand = ggplot2::expansion(add = 0.3)
  )
}

# ---------------------------------------------------------------------------
# Cor com significado único
# ---------------------------------------------------------------------------

# Séries aninhadas e ordenadas — RTB ⊂ RB3 ⊂ RB4, Top 10% ⊃ Top 1% ⊃ Top 0,1% —
# pedem rampa sequencial: a intensidade passa a codificar a ordem. Paleta
# qualitativa destrói essa informação.
cor_ordinal <- function(n, inverter = FALSE) {
  if (n <= 0L) return(character())
  cores <- viridisLite::mako(max(n, 2L), begin = 0.22, end = 0.78, direction = -1)
  cores <- cores[seq_len(n)]
  if (inverter) rev(cores) else cores
}

# Okabe-Ito: paleta qualitativa segura para as formas comuns de daltonismo.
# Usada só onde as categorias não têm ordem (destaque contra contexto).
cor_destaque <- function(n = 1L) {
  paleta <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7", "#E69F00", "#56B4E9", "#000000")
  paleta[seq_len(min(n, length(paleta)))]
}

cor_contexto <- function() cores_irpf$contexto

# `contexto` nomeia séries que servem de referência e não fazem parte do
# aninhamento — "todos os declarantes" ao lado dos grupos de topo, por exemplo.
# Elas recebem cinza: entram na rampa apenas as categorias que têm ordem.
escala_cor_ordinal <- function(niveis, nome = NULL, inverter = FALSE,
                               aes = c("colour", "fill"), contexto = character()) {
  aes <- match.arg(aes)
  ordenados <- setdiff(niveis, contexto)
  valores <- c(
    stats::setNames(cor_ordinal(length(ordenados), inverter), ordenados),
    stats::setNames(rep(cor_contexto(), length(contexto)), contexto)
  )[niveis]
  if (aes == "colour") {
    ggplot2::scale_colour_manual(name = nome, values = valores, limits = niveis)
  } else {
    ggplot2::scale_fill_manual(name = nome, values = valores, limits = niveis)
  }
}

# Mapa em classes, não contínuo: com um outlier estadual a escala contínua
# colapsa o contraste das outras 26 UFs, e a legenda contínua não declara
# limite de classe nenhum.
escala_mapa_classes <- function(valores, n_classes = 5L, nome = NULL,
                                rotular = rotulo_indice(0.01)) {
  finitos <- valores[is.finite(valores)]
  if (length(finitos) < 2L) {
    return(ggplot2::scale_fill_gradientn(
      name = nome, colours = cor_ordinal(5L), na.value = "#E9ECEF"
    ))
  }
  quebras <- unique(stats::quantile(
    finitos, probs = seq(0, 1, length.out = n_classes + 1L), na.rm = TRUE
  ))
  # Valores todos iguais colapsam os quantis num ponto só, e limites de largura
  # zero quebram a escala.
  if (length(quebras) < 2L) {
    return(ggplot2::scale_fill_gradientn(
      name = nome, colours = cor_ordinal(5L), na.value = "#E9ECEF"
    ))
  }
  ggplot2::scale_fill_stepsn(
    name = nome,
    colours = cor_ordinal(max(length(quebras) - 1L, 2L)),
    breaks = quebras,
    limits = range(quebras),
    labels = rotular,
    na.value = "#E9ECEF",
    guide = ggplot2::guide_coloursteps(
      show.limits = TRUE, barwidth = grid::unit(14, "lines"),
      barheight = grid::unit(0.5, "lines")
    )
  )
}

# ---------------------------------------------------------------------------
# Anotação
# ---------------------------------------------------------------------------

# Rotula o primeiro e o último ponto da série: o leitor lê os extremos sem
# precisar mirar o eixo, que é onde o truncamento engana.
rotular_extremos <- function(dados, x, y, formatar = rotulo_indice(0.001),
                             tamanho = 3.1, cor = cores_irpf$tinta) {
  finitos <- dados[is.finite(dados[[x]]) & is.finite(dados[[y]]), , drop = FALSE]
  if (nrow(finitos) == 0L) return(NULL)
  ordenado <- finitos[order(finitos[[x]]), , drop = FALSE]
  pontos <- ordenado[unique(c(1L, nrow(ordenado))), , drop = FALSE]
  pontos$.rotulo <- formatar(pontos[[y]])
  pontos$.hjust <- if (nrow(pontos) == 2L) c(-0.15, 1.15) else 0.5
  ggplot2::geom_text(
    data = pontos,
    mapping = ggplot2::aes(
      x = .data[[x]], y = .data[[y]], label = .data$.rotulo, hjust = .data$.hjust
    ),
    inherit.aes = FALSE, size = tamanho, colour = cor, vjust = -0.9,
    show.legend = FALSE
  )
}

# Rótulo direto no fim da linha. Resolve o descasamento entre a ordem
# alfabética da legenda e a ordem vertical das linhas, que obriga o leitor a
# fazer a correspondência à mão.
rotular_series_no_fim <- function(dados, x, y, grupo, tamanho = 3.2, nudge = 0.12,
                                  separacao_min = 0.05) {
  finitos <- dados[is.finite(dados[[x]]) & is.finite(dados[[y]]), , drop = FALSE]
  if (nrow(finitos) == 0L) return(NULL)
  ultimos <- do.call(rbind, lapply(split(finitos, finitos[[grupo]]), function(bloco) {
    bloco[which.max(bloco[[x]]), , drop = FALSE]
  }))
  ultimos <- ultimos[order(ultimos[[y]]), , drop = FALSE]

  # Séries que terminam próximas fariam os rótulos se sobrepor. Empurrar de
  # baixo para cima mantém a ordem vertical — que é o que o rótulo direto
  # existe para preservar — e só desloca o necessário.
  amplitude <- diff(range(finitos[[y]], na.rm = TRUE))
  minimo <- separacao_min * ifelse(is.finite(amplitude) && amplitude > 0, amplitude, 1)
  posicoes <- ultimos[[y]]
  if (length(posicoes) > 1L) {
    for (i in seq_along(posicoes)[-1]) {
      if ((posicoes[i] - posicoes[i - 1L]) < minimo) posicoes[i] <- posicoes[i - 1L] + minimo
    }
  }
  ultimos$.y_rotulo <- posicoes

  ggplot2::geom_text(
    data = ultimos,
    mapping = ggplot2::aes(
      x = .data[[x]], y = .data$.y_rotulo, label = .data[[grupo]], colour = .data[[grupo]]
    ),
    inherit.aes = FALSE, hjust = 0, nudge_x = nudge, size = tamanho,
    show.legend = FALSE
  )
}

faixa_referencia <- function(minimo, maximo, cor = cores_irpf$grade, alpha = 0.45) {
  ggplot2::annotate(
    "rect", xmin = -Inf, xmax = Inf, ymin = minimo, ymax = maximo,
    fill = cor, alpha = alpha
  )
}

# Marca um ponto que carrega ressalva metodológica, em vez de deixá-lo passar
# como observação comum.
anotar_ressalva <- function(x, y, texto, tamanho = 3, cor = cores_irpf$texto_suave) {
  list(
    ggplot2::annotate(
      "point", x = x, y = y, shape = 21, size = 3.4, stroke = 1,
      colour = cores_irpf$tinta, fill = cores_irpf$fundo
    ),
    ggplot2::annotate(
      "text", x = x, y = y, label = texto, size = tamanho, colour = cor,
      hjust = -0.12, vjust = -1.2
    )
  )
}

# Ordena os níveis de um fator pelo valor final da série, para que a ordem da
# legenda coincida com a ordem vertical das linhas.
ordenar_por_valor_final <- function(dados, x, y, grupo) {
  finitos <- dados[is.finite(dados[[x]]) & is.finite(dados[[y]]), , drop = FALSE]
  if (nrow(finitos) == 0L) return(character())
  ultimos <- vapply(split(finitos, finitos[[grupo]]), function(bloco) {
    bloco[[y]][which.max(bloco[[x]])]
  }, numeric(1))
  names(sort(ultimos, decreasing = TRUE))
}
