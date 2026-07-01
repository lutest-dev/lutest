---
title: Filosofia
---

Esta página explica as escolhas por trás do modelo atual.

O Lutest fica mais próximo de como testes costumam ser escritos em projetos [Rust](https://rust-lang.org/) do que de um modelo baseado em arquivos de teste separados.

## Por que testes co-located

Quando os testes vivem ao lado do código que exercitam, fica mais fácil mantê-los em sincronia com esse código.

## Por que evitar APIs públicas artificiais

Helpers internos e comportamento não exportado devem continuar testáveis sem exigir APIs públicas criadas só para teste.

## Por que usar `assert`

O `assert` normal do Luau já resolve uma parte grande do problema.

O Lutest não tenta substituí-lo cedo por uma segunda DSL de assertions.

## Por que `.spec.luau` não é o contrato principal

Discovery por nome de arquivo tende a empurrar testes para arquivos separados e a moldar o código em torno dessa limitação.

O Lutest, em vez disso, trata um módulo como interessante porque ele depende do package path configurado do Lutest.
