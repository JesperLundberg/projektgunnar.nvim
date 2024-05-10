globals = {
	vim = {},
	it = {},
	describe = {},
	before_each = {},
	after_each = {},
}

ignore = {
	"631", -- max_line_length
	"212/_.*", -- unused argument, for vars with "_" prefix
	"121", -- setting read-only global variable 'vim'
	"122", -- setting read-only field of global variable 'vim'
}

-- Global objects defined by the C code
read_globals = {
	"vim",
}
