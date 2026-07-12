return {
	lute = {
		lint = {
			ignores = {
				'scripts/build-roblox-bundle.luau',
				'vendor/**',
				'luau_packages/**',
				'Packages/**',
			},
		},
	},
	luau = {
		languagemode = 'strict',
		aliases = {
			lune = '~/.lune/.typedefs/0.10.5/',
			lutest = '.',
			core = 'core',
			lib = 'lib',
			runtimes = 'runtimes',
			lutest_release = 'Packages/lutest@v0.1.9/lib',
			packages = 'luau_packages',
			std = '~/.lute/typedefs/1.0.0/std',
			lute = '~/.lute/typedefs/1.0.0/lute',
			lint = '~/.lute/typedefs/1.0.0/lint',
		},
	},
}
