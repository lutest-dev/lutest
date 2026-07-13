const tint = require '@packages/tint'

-- Keep terminal output calm: one identity color and colors for state only.
const accent = tint.hex '#8B9CFF'
const success = tint.hex '#46D39A'
const failure = tint.hex '#FF718B'
const warning = tint.hex '#F6C85F'
const todo = tint.hex '#C69CFF'
const muted = tint.hex '#8D97AA'

const function section(label: string): string
	return accent.bold(`> {label}`)
end

const function passed(label: string): string
	return success.bold(`+ {label}`)
end

const function failed(label: string): string
	return failure.bold(`x {label}`)
end

const function warned(label: string): string
	return warning.bold(`! {label}`)
end

return {
	accent = accent,
	success = success,
	failure = failure,
	warning = warning,
	todo = todo,
	muted = muted,
	section = section,
	passed = passed,
	failed = failed,
	warned = warned,
}
