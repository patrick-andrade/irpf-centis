// Só as funções do d3 que as páginas usam diretamente: o esbuild descarta o
// resto da biblioteca (o Plot já traz, por dentro, o que precisa dela).
export {
  ascending, descending, extent, group, groups, max, mean, min, quantile, range,
  rollup, sum, sort, formatLocale, geoArea, geoBounds
} from "d3";
