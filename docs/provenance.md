# Proveniência

- Arquivos oficiais são armazenados sem alteração em `data/raw/<família>/<ano>/`.
- `sources-manifest.csv` registra URL direta, URL de origem, data de recuperação, tamanho e SHA-256.
- Dados normalizados sempre conservam `source_id`, `source_file` e `source_sheet`.
- Alterações de hash em uma URL já conhecida bloqueiam a atualização automática e exigem revisão.
- O pipeline não substitui valores ausentes por zero.
- A fotografia da base da Receita pode mudar em razão de retificações; a data de extração integra a definição do dado.

