return {
	version = 2,
	dependencies = {
		['lutest@v0.6.1'] = {
			installPath = 'Packages/lutest@v0.6.1',
			name = 'lutest',
			rev = 'v0.6.1',
			source = 'https://github.com/lutest-dev/lutest',
			sourceKind = 'github',
			dependencies = {
				lutest = 'lutest@v0.6.1',
			},
		},
	},
	packages = { 'lutest@v0.6.1' },
}
