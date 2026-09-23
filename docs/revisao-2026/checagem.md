# Checagem da revisão

Execução local em Windows, R 4.6.0, Quarto 1.9.38, a partir da base pública `e9a8eff5336c66403df802e6a815cd5e57811033`. O ambiente `renv` foi restaurado sem alterar `renv.lock` e `renv::status()` não apontou divergência.

| Frente | Evidência e resultado | Limite da checagem |
|---|---|---|
| Fontes | 53 arquivos locais presentes, todos com SHA-256 igual ao manifesto; nota oficial de RB9 em 2024 conferida no metadado da Receita. | Não demonstra que o portal não tenha sido atualizado depois da coleta nem quantifica exclusões individuais. |
| Método | Testes sintéticos das fórmulas e dos cortes; comparação por arquivo, coluna e linha em [resultados](resultados.md). | Indicadores agrupados continuam sem informação intragrupo. |
| Dados e código | `Rscript scripts/run.R build`: saída 0, seis alvos reconstruídos e 114 reaproveitados na última execução; `Rscript scripts/run.R check`: saída 0, suíte completa sem testes pulados. Após a revisão do PR, o parser leu também a aba nacional `BRV` da planilha oficial de 2024: 120 códigos válidos e gate de grupos aprovado. | O parse inicial de 44 planilhas foi interrompido após três por duração; a execução final reutilizou cache de parse previamente produzido com os arquivos cujos hashes foram conferidos. CI testa código, mas não reconstrói os dados brutos. |
| Lint | O comando `check` informou 562 apontamentos em `R/` e 366 em `app/R`. | Lint é diagnóstico, sem gate de aprovação nesta revisão; a limpeza requer uma frente própria. |
| Site e painel | `quarto render . --execute`: sete páginas, inclusive três PDFs. Replay com `RENV_CONFIG_AUTOLOADER_ENABLED=false quarto render`: saída 0. Exportação shinylive: saída 0. Nove HTMLs gerados, sem referência local ausente no verificador de `href` e `src`; fontes Noto embutidas nos PDFs. | A verificação visual em navegador local foi bloqueada pela política da ferramenta; a conferência do site publicado permanece na etapa de Pages. |
| Publicação | `git diff --check`: saída 0; Git público ignora `internal/`, planilhas oficiais e saídas processadas locais. | CI e Pages ainda dependem do push, PR e merge desta branch. |

A checagem do site no GitHub Pages deve incluir navegação em desktop e celular, filtros do painel, teclado, textos alternativos, notas de 2018, fontes, unidades e PDF. Se algum desses pontos divergir do render local, a correção deve entrar no código público e ser registrada no histórico.
