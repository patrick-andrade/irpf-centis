# Política de segurança

## Versões cobertas

O projeto publica um site estático e um painel que roda inteiramente no
navegador do leitor. Não há servidor, banco de dados nem autenticação. A versão
coberta é sempre a mais recente publicada em `main`.

## Relatando uma vulnerabilidade

**Não abra uma issue pública** para relatar vulnerabilidade.

Use o canal privado do GitHub: aba
[Security](https://github.com/patrick-andrade/irpf-centis/security/advisories/new)
do repositório → *Report a vulnerability*. A resposta costuma sair em até 15
dias; correções aceitas são publicadas junto com o aviso.

Ajuda muito descrever o impacto concreto, o passo a passo para reproduzir e a
versão ou commit onde você observou o problema.

## O que está no escopo

- Execução de código ou injeção pelo painel shinylive ou pelas páginas do site.
- Comprometimento da cadeia de build: workflows do GitHub Actions, dependências
  do `renv.lock`, scripts de aquisição de dados.
- Qualquer credencial, token ou dado pessoal que tenha vazado para o
  repositório ou para o site — inclusive no histórico.

## O que não está no escopo

- Conteúdo dos arquivos oficiais da Receita Federal e do IBGE; reporte à fonte.
- Divergências de dados e erros de método: são issues públicas normais, e
  bem-vindas. Veja [CONTRIBUTING.md](CONTRIBUTING.md).
- Configuração do GitHub Pages fora do controle deste repositório.

## Nota sobre dados pessoais

Este projeto trabalha apenas com dados **agregados** publicados oficialmente —
totais e médias por grupo de cem ou mais declarações. Não há microdado
individual, e nenhum arquivo bruto é redistribuído aqui: o manifesto registra
URL, data de recuperação e SHA-256 para que cada arquivo seja buscado na origem.
Se ainda assim você identificar risco de reidentificação em algo publicado aqui,
trate como vulnerabilidade e use o canal privado acima.
