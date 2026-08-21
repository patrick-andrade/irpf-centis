# Como contribuir

Este é um projeto de análise reprodutível. Contribuições de código são
bem-vindas, mas o retorno mais útil costuma ser sobre os números e o método.

## Tipos de contribuição

1. **Erro nos dados ou nos indicadores.** Informe o valor, o ano, a geografia e
   o conceito de renda, e contra o quê a comparação foi feita — o arquivo
   oficial, outra publicação, uma identidade contábil. Se possível, aponte a
   célula da fonte.
2. **Discordância de método.** As escolhas conceituais estão em
   [`docs/methodology.md`](docs/methodology.md), [`docs/limitations.md`](docs/limitations.md)
   e nos registros de decisão em [`docs/decisions/`](docs/decisions). Discutir a
   escolha registrada tende a ser mais produtivo do que discutir o resultado
   dela.
3. **Clareza.** Um gráfico que induz ao erro, um texto ambíguo, um rótulo que
   não se explica sozinho.
4. **Acessibilidade do painel e dos relatórios.**
5. **Código:** correções de bug, testes, desempenho.

## Abrindo uma issue

Use os modelos em [Issues](https://github.com/patrick-andrade/irpf-centis/issues/new/choose).
Antes, dê uma busca nas issues existentes — inclusive nas fechadas.

Antes disso, vale saber o que **não** é erro do projeto: divergências que já
existem nos arquivos da Receita são preservadas de propósito e exportadas como
avisos, nunca corrigidas em silêncio. O ano-calendário 2018 e as divergências
monetárias da RTB subnacional em 2017–2021 estão documentados em
[`docs/limitations.md`](docs/limitations.md).

## Enviando código

O projeto está em **beta público** e o método ainda se move. Abra uma issue
antes de escrever código: além de evitar trabalho perdido numa parte que está
para mudar, é por ali que combinamos como executar o pipeline localmente, o que
não está documentado nesta fase.

Combinado o caminho, o pull request deve:

1. Sair de um fork, num branch com nome descritivo.
2. Passar em testes e lint.
3. Descrever o que muda e, quando houver mudança de número publicado, qual
   número mudou e por quê.

### Convenções

- Código e comentários em português, UTF-8 preservado.
- Arquivos-fonte em caixa baixa (`kebab-case` ou `snake_case`).
- Nomes de objetos e colunas em inglês, seguindo os contratos de
  [`config/schema/`](config/schema); o texto voltado ao leitor, em português.
- Toda mudança de comportamento vem com teste. Mudança em indicador ou parser
  vem com teste sobre fixture sintética.
- Nada de credencial, token ou dado bruto no repositório.
- Mensagens de commit no formato `tipo: descrição` (`fix:`, `feat:`, `docs:`,
  `test:`, `refactor:`).

## Escopo

O projeto é descritivo por decisão: mede e documenta, não estima causa nem
projeta cenário. Propostas que mudem essa natureza provavelmente serão
recusadas — mas a discussão numa issue é bem-vinda antes de qualquer trabalho.

## Conduta

A participação segue o [Código de Conduta](CODE_OF_CONDUCT.md).

## Licença da contribuição

Ao contribuir, você concorda em licenciar código sob [MIT](LICENSE) e textos sob
[CC BY-SA 4.0](LICENSE-docs.md), como o restante do projeto.
