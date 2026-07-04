return {
	version = 2,
	dependencies = {
		['lutest@v0.1.6'] = {
			installPath = 'Packages/lutest@v0.1.6',
			name = 'lutest',
			rev = 'v0.1.6',
			source = 'https://github.com/cayasde/lutest',
			sourceKind = 'github',
			dependencies = {
				lutest = 'lutest@v0.1.6',
			},
		},
	},
	packages = { 'lutest@v0.1.6' },
}
