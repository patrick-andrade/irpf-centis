// Estado da visão: link compartilhável e filtros comuns entre as páginas.
//
// O leitor escolhe ano e geografia numa página e espera reencontrá-los na
// seguinte; e quer mandar a alguém "o top 1% de SP em 2023" sem descrever
// cliques. Os nomes dos parâmetros são os do painel antigo (shinylive), para
// que links antigos continuem valendo depois do redirecionamento.

export const paginas = Object.freeze([
  { id: "visao-geral", arquivo: "index.html", titulo: "Visão geral" },
  { id: "evolucao", arquivo: "evolucao.html", titulo: "Evolução" },
  { id: "topos", arquivo: "topos.html", titulo: "Topos da renda" },
  { id: "rendimentos", arquivo: "rendimentos.html", titulo: "Rendimentos e imposto" },
  { id: "bens", arquivo: "bens.html", titulo: "Bens" },
  { id: "dividas", arquivo: "dividas.html", titulo: "Dívidas" },
  { id: "estados", arquivo: "estados.html", titulo: "Estados e regiões" },
  { id: "dados", arquivo: "dados.html", titulo: "Dados" }
]);

export const paginasComAno = Object.freeze(["topos", "rendimentos", "bens", "dividas", "estados"]);
export const paginasComGeo = Object.freeze(["evolucao", "topos", "rendimentos", "bens", "dividas"]);

const CHAVE_SESSAO = "irpf-estado";

// Lê a query e devolve só o que vale para os dados publicados. Valor
// desconhecido (link antigo, digitação) cai no padrão da página em vez de
// quebrar a abertura.
export function lerEstado(busca, { anos = [], geos = [], indicadores = [], conceitos = [], grupos = [], abas = paginas.map((p) => p.id) } = {}) {
  const campos = new URLSearchParams(busca ?? "");
  const valido = (nome, permitidos) => {
    const valores = campos.getAll(nome);
    if (valores.length !== 1) return null;
    return permitidos.map(String).includes(valores[0]) ? valores[0] : null;
  };
  const lista = (nome, permitidos, maximo) => {
    const valor = campos.get(nome);
    if (valor === null) return null;
    const permitidosTexto = permitidos.map(String);
    const partes = [...new Set(valor.split(","))].filter((p) => permitidosTexto.includes(p));
    return partes.length === 0 ? null : partes.slice(0, maximo);
  };
  return {
    aba: valido("aba", abas),
    ano: valido("ano", anos),
    geo: valido("geo", geos),
    comparar: lista("comparar", geos, 2),
    ind: valido("ind", indicadores),
    conceito: valido("conceito", conceitos),
    grupo: valido("grupo", grupos),
    sem_topo: campos.get("sem_topo") === "1",
    ordem: valido("ordem", ["valor", "nome", "regiao"])
  };
}

// Monta a query a partir de pares nomeados, na ordem dada. Valores nulos,
// falsos ou vazios saem; verdadeiro vira "1"; listas são unidas por vírgula.
// Os valores vêm de vocabulário controlado (códigos, ids de indicador).
export function montarQuery(parametros) {
  const partes = [];
  for (const [nome, valor] of Object.entries(parametros)) {
    if (valor === null || valor === undefined || valor === false) continue;
    const texto = valor === true ? "1" : Array.isArray(valor) ? valor.join(",") : String(valor);
    if (texto === "") continue;
    partes.push(`${nome}=${encodeURIComponent(texto).replace(/%2C/gi, ",")}`);
  }
  return partes.length ? `?${partes.join("&")}` : "";
}

export function lerSessao(armazenamento = globalThis.sessionStorage) {
  try {
    return JSON.parse(armazenamento?.getItem(CHAVE_SESSAO) ?? "{}") ?? {};
  } catch {
    return {};
  }
}

export function gravarSessao(parcial, armazenamento = globalThis.sessionStorage) {
  try {
    const atual = lerSessao(armazenamento);
    armazenamento?.setItem(CHAVE_SESSAO, JSON.stringify({ ...atual, ...parcial }));
  } catch {
    // Navegação privada pode bloquear o armazenamento; o link continua valendo.
  }
}

// Valor inicial de um filtro: o da URL; senão o da sessão (o leitor vindo de
// outra página); senão o padrão. Só vale se estiver entre as escolhas.
export function valorInicial(daUrl, campo, escolhas, padrao, sessao = lerSessao()) {
  const texto = escolhas.map(String);
  if (daUrl !== null && daUrl !== undefined && texto.includes(String(daUrl))) return daUrl;
  const salvo = sessao?.[campo];
  if (salvo !== null && salvo !== undefined && texto.includes(String(salvo))) return salvo;
  return padrao;
}

// Espelha a visão na URL (sem recarregar) e guarda ano e geografia para as
// outras páginas. Atualiza os links da subnavegação com o estado comum.
export function publicarEstado(parametros, { comum = {} } = {}) {
  const query = montarQuery(parametros);
  if (typeof history !== "undefined" && typeof location !== "undefined") {
    history.replaceState(history.state, "", `${location.pathname}${query}${location.hash}`);
  }
  gravarSessao(comum);
  atualizarSubnav(comum);
  return query;
}

export function hrefComEstado(pagina, comum = {}) {
  const parametros = {};
  if (paginasComGeo.includes(pagina.id) && comum.geo) parametros.geo = comum.geo;
  if (paginasComAno.includes(pagina.id) && comum.ano) parametros.ano = comum.ano;
  return `${pagina.arquivo}${montarQuery(parametros)}`;
}

export function atualizarSubnav(comum = {}, raiz = globalThis.document) {
  if (!raiz?.querySelectorAll) return;
  for (const link of raiz.querySelectorAll("nav.subnav-explorar a[data-pagina]")) {
    const pagina = paginas.find((p) => p.id === link.dataset.pagina);
    if (pagina) link.setAttribute("href", hrefComEstado(pagina, comum));
  }
}

// Copia o endereço da visão. Sem a API de área de transferência (http, iframe
// sem permissão), oferece o endereço num prompt para cópia manual.
export async function copiarLink(botao, { endereco = globalThis.location?.href } = {}) {
  const original = botao?.dataset?.rotulo ?? botao?.textContent;
  const avisar = (texto) => {
    if (!botao) return;
    botao.dataset.rotulo = original;
    botao.textContent = texto;
    setTimeout(() => { botao.textContent = original; }, 2500);
  };
  try {
    await navigator.clipboard.writeText(endereco);
    avisar("Link copiado");
  } catch {
    globalThis.prompt?.("Copie o link desta visão:", endereco);
  }
}
