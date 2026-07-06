return {
	lute = {
		lint = {
			ignores = {
				'vendor/**',
				'luau_packages/**',
				'Packages/**',
			},
		},
	},
	luau = {
		languagemode = 'strict',
		aliases = {
			lutest = '.',
			core = 'core',
			lib = 'lib',
			runtimes = 'runtimes',
			lutest_release = 'Packages/lutest@v0.1.8/lib',
			packages = 'luau_packages',
			std = '~/.lute/typedefs/1.0.0/std',
			lute = '~/.lute/typedefs/1.0.0/lute',
			lint = '~/.lute/typedefs/1.0.0/lint',
		},
	},
}
