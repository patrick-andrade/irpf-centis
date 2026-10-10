// Visão atual do painel na URL da página.
//
// O shinylive abre o app num iframe cuja URL não traz a query da página:
// `/app/?geo=SP` carrega o iframe em `/app/app_<hash>/`. Os dois são da mesma
// origem, então o iframe lê e escreve a URL da página-mãe. Este arquivo roda no
// <head>, antes de o Shiny iniciar, para que `session$clientData$url_search` já
// chegue com a visão pedida no link.
(function () {
  var pagina = window;
  try {
    if (window.parent && window.parent !== window && window.parent.location.href) {
      pagina = window.parent;
    }
  } catch (e) {
    pagina = window;
  }

  try {
    if (pagina !== window && pagina.location.search && !window.location.search) {
      window.history.replaceState(null, "", window.location.pathname + pagina.location.search);
    }
  } catch (e) {}

  function urlDaVisao() {
    try {
      return pagina.location.href;
    } catch (e) {
      return window.location.href;
    }
  }

  window.irpfCopiarLink = function (botao) {
    var url = urlDaVisao();
    var original = botao.getAttribute("data-rotulo") || botao.textContent;
    botao.setAttribute("data-rotulo", original);
    function avisar(texto) {
      botao.textContent = texto;
      setTimeout(function () { botao.textContent = original; }, 2500);
    }
    function manual() {
      window.prompt("Copie o link desta visão:", url);
    }
    var area = navigator.clipboard;
    if (!area && pagina.navigator) area = pagina.navigator.clipboard;
    if (area && area.writeText) {
      area.writeText(url).then(function () { avisar("Link copiado"); }, manual);
    } else {
      manual();
    }
  };

  document.addEventListener("DOMContentLoaded", function () {
    if (!window.Shiny || !window.Shiny.addCustomMessageHandler) return;
    window.Shiny.addCustomMessageHandler("estado-url", function (msg) {
      var busca = msg && msg.query ? msg.query : "";
      try {
        pagina.history.replaceState(null, "", pagina.location.pathname + busca + pagina.location.hash);
      } catch (e) {}
      if (pagina !== window) {
        try {
          window.history.replaceState(null, "", window.location.pathname + busca);
        } catch (e) {}
      }
    });
  });
})();
