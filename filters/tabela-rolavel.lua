-- Envolve cada tabela numa região rolável, para que ela role dentro do próprio
-- contêiner em vez de alargar a página em telas estreitas.
--
-- A regra `.cell-output-display:has(table)` de styles/site.scss não alcança as
-- tabelas que chegam como markdown: kable com `results: asis` e as tabelas pipe
-- dos .md ficam soltas na seção. Daí o filtro, e não só CSS.
--
-- A região é focável (tabindex="0") para rolar pelo teclado e leva nome
-- acessível: a legenda da tabela, ou, sem legenda, o título da seção. A tabela
-- continua sendo <table> e mantém a semântica para leitores de tela; pôr
-- `display: block` nela custaria isso.

local contador = 0
local ultimo_titulo = nil

local function envolver(tabela)
  contador = contador + 1
  local atributos = { role = "region", tabindex = "0" }

  if #tabela.caption.long > 0 then
    -- O nome vem da própria legenda (aria-labelledby), sem repetir o texto num
    -- atributo: o id vai num <span> dentro do <caption>.
    local base = tabela.identifier ~= "" and tabela.identifier or ("tabela-" .. contador)
    local id = base .. "-legenda"
    local texto = pandoc.utils.blocks_to_inlines(tabela.caption.long)
    tabela.caption.long = pandoc.Blocks({ pandoc.Plain({ pandoc.Span(texto, pandoc.Attr(id)) }) })
    atributos["aria-labelledby"] = id
  elseif ultimo_titulo then
    -- Texto, e não aria-labelledby: no HTML o id do título vai para a <section>
    -- inteira, e o nome viraria o texto da seção toda.
    atributos["aria-label"] = ultimo_titulo
  else
    atributos["aria-label"] = "Tabela"
  end

  return pandoc.Div({ tabela }, pandoc.Attr("", { "tabela-rolavel" }, atributos))
end

return {
  {
    -- Ordem do documento, para que o "último título" seja o que precede a tabela.
    traverse = "topdown",
    Header = function(titulo)
      ultimo_titulo = pandoc.utils.stringify(titulo)
    end,
    Table = function(tabela)
      if not quarto.doc.is_format("html") then return nil end
      -- `false` impede a descida na Div nova, que reencontraria a mesma tabela.
      return envolver(tabela), false
    end
  }
}
