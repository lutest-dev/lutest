return {
	version = 2,
	dependencies = {
		['lutest@v0.7.1'] = {
			installPath = 'Packages/lutest@v0.7.1',
			name = 'lutest',
			rev = 'v0.7.1',
			source = 'https://github.com/lutest-dev/lutest',
			sourceKind = 'github',
			dependencies = {
				lutest = 'lutest@v0.7.1',
			},
		},
	},
	packages = { 'lutest@v0.7.1' },
}
