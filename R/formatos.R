# Formatadores em português usados nas tabelas e textos dos relatórios e nas
# fixtures compartilhadas com o JavaScript (tests/fixtures/formatos-ptbr.json).
# Os gráficos são desenhados pelo módulo JS (js/), com d3.formatLocale; estas
# funções precisam escrever os mesmos números, e o teste das fixtures confere.

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

# Precisão uniforme dentro do mesmo eixo: alternar entre uma e duas casas faz a
# sequência "99,8 / 99,90 / 99,91" parecer um retrocesso e trava a leitura.
formatar_percentil <- function(x, accuracy = NULL) {
  if (is.null(accuracy)) accuracy <- if (any(x >= 0.999, na.rm = TRUE)) 0.01 else 0.1
  scales::number(100 * x, accuracy = accuracy, decimal.mark = ",", big.mark = ".")
}
