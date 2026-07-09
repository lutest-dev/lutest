return {
	version = 2,
	dependencies = {
		['lutest@v0.1.11'] = {
			installPath = 'Packages/lutest@v0.1.11',
			name = 'lutest',
			rev = 'v0.1.11',
			source = 'https://github.com/cayasde/lutest',
			sourceKind = 'github',
			dependencies = {
				lutest = 'lutest@v0.1.11',
			},
		},
	},
	packages = { 'lutest@v0.1.11' },
}
