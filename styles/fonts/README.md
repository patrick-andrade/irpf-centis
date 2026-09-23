# Fontes do site e dos PDFs

O site e os PDFs usam Noto Sans e Noto Sans Display, distribuídas sob a SIL
Open Font License 1.1. Os textos de licença estão nesta pasta. Os arquivos
originais vieram do repositório oficial
[google/fonts](https://github.com/google/fonts) no commit
`e44c4b011a820c2cbe2fd2cfa8052037d7edb571`:

- `ofl/notosans/NotoSans[wdth,wght].ttf` — SHA-256 `BFB7BB691513F12E734DC346C03A03F784912432D7E3FA8E56EFCF906FE86B3D`.
- `ofl/notosansdisplay/NotoSansDisplay[wdth,wght].ttf` — SHA-256 `DEAA68141FA5AD21BD17D7C11FA79183CEDA19B32E40FF5C33874D42F3636DDE`.

Instâncias estáticas foram geradas com fonttools 4.59.2 em largura 100 e pesos
400/700, pois a versão de Typst usada pelo Quarto não renderiza fontes
variáveis de modo confiável. Elas são incorporadas aos PDFs e servidas pelo
site Quarto:

- `NotoSans-Regular.ttf` — SHA-256 `FC3555F8484BC3DC45516E5E10E1F2389512F52DB988F2FFDDCE494188494C0A`.
- `NotoSans-Bold.ttf` — SHA-256 `AC60698A14004F41E75F41BD2EE1A165CBB537D36D95F5222B748058A0DA56CC`.
- `NotoSansDisplay-Bold.ttf` — SHA-256 `ABEC934E50AF08AE4CF2705450FB4F1293129B549907FCC680B6E9BDC8EEE2B6`.

Fontes de sistema continuam disponíveis como fallback no navegador.
