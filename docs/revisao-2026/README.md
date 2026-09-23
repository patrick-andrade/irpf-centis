# Revisão do estudo IRPF — setembro de 2026

Esta pasta registra a revisão da versão pública. O site Quarto usa uma lista
explícita de páginas e não renderiza estes arquivos; eles continuam acessíveis
no repositório para que método, evidência e decisões sobrevivam à troca de
agentes. O [método](../methodology.md), as [limitações](../limitations.md) e as
[instruções de reprodução](../reproducibility.md) são os textos de referência
para quem lê os resultados.

Leia o [diagnóstico](diagnostico.md), a [matriz de fontes](fontes-e-universo.md),
a [comparação numérica](resultados.md) e a [checagem](checagem.md) desta rodada.

## Fases e responsáveis

| Frente | Análise | Revisão | Checagem |
|---|---|---|---|
| Fontes e universo | Comparar manifesto, metadados e cobertura por edição | Corrigir afirmações sobre unidade, ranking e comparabilidade | Hash, regra oficial, grupo e texto publicado associados em [fontes e universo](fontes-e-universo.md) |
| Indicadores | Conferir pesos, grupos disjuntos, fórmulas e denominadores com fonte primária e exemplos calculados à parte | Corrigir código, contrato e explicação juntos | Testes sintéticos e comparação integral com produtos anteriores |
| Código e reprodução | Examinar aquisição, parsers, gates, pipeline, CI e `renv` | Corrigir falhas demonstradas com testes de regressão | `check`, build, render e estado do ambiente registrados |
| Texto | Revisar utilidade para leitor e colaborador | Simplificar contribuição, publicar limites e reprodução | Links, coerência entre README e método, diff sem dados brutos |
| Visualização | Avaliar hierarquia, gráficos e ressalvas | Aplicar identidade própria inspirada na [OECD](https://www.oecd.org/en/publications/oecd-economic-outlook-volume-2026-issue-1_2d1956f0-en.html) | HTML/PDF, painel, dispositivos, teclado, contraste, unidades e fonte |

Pesquisa e cálculo podem ser conferidos em paralelo; mudanças no mesmo arquivo
e a decisão sobre publicação passam pela integração. O registro operacional e
as passagens detalhadas entre agentes ficam em repositório privado separado.
Nenhum dado bruto nem credencial integra esta pasta.

## Critério para concluir

Uma diferença numérica precisa de causa identificada, recorte afetado e nota
pública. Uma correção visual não deve esconder ressalvas nem alterar escala de
modo enganoso. A versão 0.3.0 já arquivada no Zenodo não é substituída por
esta rodada: o [changelog](../../CHANGELOG.md) registra as correções ainda não
lançadas e o commit permite identificar o estado do site.
