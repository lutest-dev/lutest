---
title: Rodando Testes
---

Depois que existe um módulo de teste, rodar fica simples.

Sem argumentos, o Lutest usa os `roots` de `lutest.toml`:

```powershell
lutest
```

Se você quiser rodar só um path, passe esse path:

```powershell
lutest tests
```

Você também pode passar mais de um path:

```powershell
lutest src tests
```

Esse é o formato inteiro da CLI atual. Você passa os paths, e o Lutest roda os módulos de teste que encontrar ali.

Se o discovery não encontrar nada, o Lutest sai com status de falha e imprime:

```text
no test modules found
```

Quando os testes rodam, a saída é agrupada pelo path do módulo. Você vai ver totais de testes passados, falhos, pulados e `todo`, além das mensagens de erro por teste quando algo falhar.
