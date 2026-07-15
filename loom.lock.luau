return {
	version = 2,
	dependencies = {
		['lutest@v0.6.0'] = {
			installPath = 'Packages/lutest@v0.6.0',
			name = 'lutest',
			rev = 'v0.6.0',
			source = 'https://github.com/lutest-dev/lutest',
			sourceKind = 'github',
			dependencies = {
				lutest = 'lutest@v0.6.0',
			},
		},
	},
	packages = { 'lutest@v0.6.0' },
}
