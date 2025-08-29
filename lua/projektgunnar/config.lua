local M = {}

M.options = {}

local defaults = {
	prefer = { "telescope", "mini" },
}

M.options = vim.deepcopy(defaults)

function M.setup(opts)
	-- Directly apply user options to M.options
	M.options = vim.tbl_deep_extend("force", {}, defaults, opts or {})
end

return M
