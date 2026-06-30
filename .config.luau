return {
	lute = {
		lint = {
			ignores = {
				'vendor/**',
				'luau_packages/**',
			},
		},
	},
	luau = {
		languagemode = 'strict',
		aliases = {
			lutest = '.',
			core = 'core',
			runtimes = 'runtimes',
			tests = 'tests',
			packages = 'luau_packages',
			std = '~/.lute/typedefs/1.0.0/std',
			lute = '~/.lute/typedefs/1.0.0/lute',
			lint = '~/.lute/typedefs/1.0.0/lint',
		},
	},
}
