# Fontes do site e dos PDFs

O site e os PDFs usam Noto Sans e Noto Sans Display, distribuídas sob a SIL
Open Font License 1.1. Os textos de licença estão nesta pasta. Os arquivos
originais vieram do repositório oficial
[google/fonts](https://github.com/google/fonts) no commit
`e44c4b011a820c2cbe2fd2cfa8052037d7edb571`:

- `ofl/notosans/NotoSans[wdth,wght].ttf` — SHA-256 `BFB7BB691513F12E734DC346C03A03F784912432D7E3FA8E56EFCF906FE86B3D`.
- `ofl/notosansdisplay/NotoSansDisplay[wdth,wght].ttf` — SHA-256 `DEAA68141FA5AD21BD17D7C11FA79183CEDA19B32E40FF5C33874D42F3636DDE`.

Instâncias estáticas foram geradas com fonttools 4.59.2, pois a versão de
Typst usada pelo Quarto não renderiza fontes variáveis de modo confiável. Elas
são incorporadas aos PDFs e servidas pelo site Quarto:

- `NotoSans-Regular.ttf` (largura 100, peso 400) — SHA-256 `FC3555F8484BC3DC45516E5E10E1F2389512F52DB988F2FFDDCE494188494C0A`.
- `NotoSans-Bold.ttf` (largura 100, peso 700) — SHA-256 `AC60698A14004F41E75F41BD2EE1A165CBB537D36D95F5222B748058A0DA56CC`.
- `NotoSansDisplay-CondensedBold.ttf` (largura 75, peso 700) — SHA-256 `919FFFC86911C8071EB031ED2AE570EDC30E08D9EB6765CBB90BD4DD2881C136`.

A condensada é a fonte dos títulos, no site e nos PDFs. A fonte variável não
traz valores de eixo no STAT, e por isso o instancer não renomeia a instância
sozinho: a família foi gravada como "Noto Sans Display Condensed", estilo
"Bold", PostScript `NotoSansDisplay-CondensedBold`, com `usWidthClass` 3 e
`usWeightClass` 700. O navegador a encontra por esse nome, declarado no
`@font-face` de `styles/site.scss`. O Typst descarta o sufixo de largura e a
lista como "Noto Sans Display" com `stretch` 75% (`quarto typst fonts
--font-path styles/fonts --variants`), e é assim que `reports/_metadata.yml` a
pede.

Fontes de sistema continuam disponíveis como fallback no navegador.

O navegador recebe versões woff2 com subconjunto latino (U+0000–017F,
diacríticos combinantes, grego, pontuação geral, moedas, símbolos de letra,
setas e operadores matemáticos), geradas com fonttools 4.59.2 e brotli a
partir das instâncias acima, mantendo todas as features OpenType (`tnum`
inclusive):

```
pyftsubset <fonte>.ttf --unicodes="U+0000-017F,U+0300-036F,U+0370-03FF,U+2000-206F,U+20A0-20CF,U+2100-214F,U+2190-21FF,U+2200-22FF" --layout-features='*' --flavor=woff2
```

- `NotoSans-Regular.woff2` — SHA-256 `D4E000C5892B7827CDA26C6B626929253925151FC1B563517F796F2C9B5F868C`.
- `NotoSans-Bold.woff2` — SHA-256 `19DA621974C6217587CAC3735EFBDB72740688DDB0FB11A90140B10B2A00D1C0`.
- `NotoSansDisplay-CondensedBold.woff2` — SHA-256 `CF88542098CAD394CB720D141CE34621E62124EDF7B0F262B1671E683D447E2F`.

O site declara a woff2 primeiro e o TTF como alternativa; os PDFs seguem
com os TTF. As figuras dos relatórios (`reports/figuras/*.svg`) pedem "Noto
Sans", que o Typst encontra nos TTF desta pasta; `tests/js/glifos.test.mjs`
falha se algum caractere de uma figura não existir na fonte, porque o Typst
trocaria a fonte do texto inteiro.
