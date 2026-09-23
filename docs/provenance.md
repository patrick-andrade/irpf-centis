# Proveniência

- Arquivos oficiais são armazenados sem alteração em `data/raw/<família>/<ano>/`.
- `sources-manifest.csv` registra URL direta, URL de origem, data de recuperação, tamanho e SHA-256.
- Dados normalizados sempre conservam `source_id`, `source_file` e `source_sheet`.
- Para uma URL já registrada, o download e o uso de cópia local exigem o mesmo SHA-256 do manifesto. Uma divergência bloqueia a atualização; o arquivo local não é substituído pelo download e o manifesto permanece intacto até a revisão da fonte.
- Uma fonte nova não adota um arquivo local preexistente sem hash registrado. O inventário também é conferido quanto a destinos duplicados antes do primeiro download.
- O pipeline não substitui valores ausentes por zero.
- A fotografia da base da Receita pode mudar em razão de retificações; a data de extração integra a definição do dado.

