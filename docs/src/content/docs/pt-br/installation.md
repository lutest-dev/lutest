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

## Loom

Hoje, se você quiser consumir o Lutest como package dentro de um projeto `lute`, o caminho prático é o Loom.

`pesde` e `wally` não encaixam bem no formato atual do Lutest, então este projeto usa o fluxo de package do próprio `lute`.

Crie um `loom.config.luau` na raiz do projeto:

```luau
return {
	package = {
		name = "my-project",
		version = "0.1.1",
		dependencies = {
			lutest = {
				name = "lutest",
				rev = "v0.1.1",
				sourceKind = "github",
				source = "https://github.com/cayasde/lutest",
			},
		},
	},
}
```

Depois instale com:

```sh
lute pkg install
```

Isso gera `loom.lock.luau` e instala a dependency em `Packages/`.

Quando você quiser ir para uma release mais nova, troque `rev` para a nova tag e rode `lute pkg install` de novo.
