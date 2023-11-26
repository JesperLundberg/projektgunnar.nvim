local nugets = require("projektgunnar.nugets")

local M = {}

function M.run_command_under_cursor()
	local line = vim.api.nvim_get_current_line()
	local command = vim.trim(line)

	-- echo command
	print(command)

	if command == "Update all nugets in project" then
		nugets.update_packages_in_project()
	elseif command == "Update all nugets in solution" then
		nugets.update_packages_in_solution()
	end
end

return M
