---
title: Lutest
description: Um test runner para projetos Luau, hoje centrado no runtime lute e em testes co-located.
---

Lutest é um test runner para projetos Luau.

Hoje ele é voltado ao runtime `lute`. O trabalho dele é simples: deixar os testes perto do código que exercitam sem obrigar cada módulo a virar uma forma especial só para teste.

Este é o menor exemplo útil:

```luau
local t = require("@lib")

t.test("adds numbers", function()
	assert(1 + 2 == 3)
end)
```

Quando você roda o Lutest, esse módulo é descoberto, carregado e tratado como uma suite.

Isso leva a três diferenças práticas:

- testes podem viver ao lado de módulos normais
- módulos não precisam retornar objetos de suite
- helpers internos podem continuar testáveis sem APIs públicas artificiais

Se você já usou o test runner embutido do `lute`, a maior mudança está no discovery. O Lutest não gira em torno de `*.test.luau` ou `*.spec.luau` como contrato principal.

## Comece aqui

1. Vá para [Instalação](./installation/).
2. Siga [Primeiro Teste](./first-test/).
3. Continue em [Rodando Testes](./running-tests/).
