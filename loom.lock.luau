return {
	version = 2,
	dependencies = {
		['lutest@v0.1.9'] = {
			installPath = 'Packages/lutest@v0.1.9',
			name = 'lutest',
			rev = 'v0.1.9',
			source = 'https://github.com/cayasde/lutest',
			sourceKind = 'github',
			dependencies = {
				lutest = 'lutest@v0.1.9',
			},
		},
	},
	packages = { 'lutest@v0.1.9' },
}
