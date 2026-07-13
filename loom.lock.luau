return {
	version = 2,
	dependencies = {
		['lutest@v0.4.0'] = {
			installPath = 'Packages/lutest@v0.4.0',
			name = 'lutest',
			rev = 'v0.4.0',
			source = 'https://github.com/cayasde/lutest',
			sourceKind = 'github',
			dependencies = {
				lutest = 'lutest@v0.4.0',
			},
		},
	},
	packages = { 'lutest@v0.4.0' },
}
