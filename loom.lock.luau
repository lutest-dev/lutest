return {
	version = 2,
	dependencies = {
		['lutest@v0.5.0'] = {
			installPath = 'Packages/lutest@v0.5.0',
			name = 'lutest',
			rev = 'v0.5.0',
			source = 'https://github.com/lutest-dev/lutest',
			sourceKind = 'github',
			dependencies = {
				lutest = 'lutest@v0.5.0',
			},
		},
	},
	packages = { 'lutest@v0.5.0' },
}
