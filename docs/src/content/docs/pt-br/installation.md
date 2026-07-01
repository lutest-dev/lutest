---
title: Instalação
---

Você pode instalar o Lutest com um toolchain manager.

## mise

Adicione o Lutest no seu `mise.toml` local:

```toml
[tools]
"github:cayasde/lutest" = "latest"
```

Depois instale a tool:

```sh
mise install
```

Em seguida, você já pode rodar:

```sh
lutest --help
```

## Rokit

Se você usa Rokit, adicione o Lutest com:

```sh
rokit add cayasde/lutest
```

Depois confirme a instalação:

```sh
lutest --help
```

## Observações

Hoje o Lutest é distribuído por GitHub Releases.

Se você quiser um setup reproduzível, fixe uma versão específica na configuração da sua toolchain em vez de usar a latest release.
