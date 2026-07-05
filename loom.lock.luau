return {
	version = 2,
	dependencies = {
		['lutest@v0.1.7'] = {
			installPath = 'Packages/lutest@v0.1.7',
			name = 'lutest',
			rev = 'v0.1.7',
			source = 'https://github.com/cayasde/lutest',
			sourceKind = 'github',
			dependencies = {
				lutest = 'lutest@v0.1.7',
			},
		},
	},
	packages = { 'lutest@v0.1.7' },
}
