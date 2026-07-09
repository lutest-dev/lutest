return {
	version = 2,
	dependencies = {
		['lutest@v0.1.12'] = {
			installPath = 'Packages/lutest@v0.1.12',
			name = 'lutest',
			rev = 'v0.1.12',
			source = 'https://github.com/cayasde/lutest',
			sourceKind = 'github',
			dependencies = {
				lutest = 'lutest@v0.1.12',
			},
		},
	},
	packages = { 'lutest@v0.1.12' },
}
