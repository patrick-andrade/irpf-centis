// Entrada do bundle servido às páginas Explorar (assets/js/irpf-viz.js).
// As páginas importam daqui o Plot fixado pelo package-lock, e não o Plot que o
// runtime OJS do Quarto buscaria no CDN (0.6.11), para que site e PDFs usem a
// mesma versão e a página funcione sem acesso a terceiros.
export * as Plot from "@observablehq/plot";
export * as d3 from "./d3.js";
export { html, svg } from "htl";
export * from "./tokens.js";
export * from "./formatos.js";
export * from "./escalas.js";
export * from "./marcas.js";
export * from "./estado.js";
export * from "./csv.js";
export * from "./dados.js";
export * from "./interface.js";
