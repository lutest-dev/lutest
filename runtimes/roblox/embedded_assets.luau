export type EmbeddedAssets = {
	library: { [string]: string },
	bundle_script: string,
}

return {
	library = {},
	bundle_script = '',
} :: EmbeddedAssets
