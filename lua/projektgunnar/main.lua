local command_handling = require("projektgunnar.command_handling")
local utils = require("projektgunnar.utils")

local M = {}

function M.show_all_commands()
	utils.open_window()
	utils.set_mappings()
	local command = {}
	table.insert(command, "Update all nugets in project")
	table.insert(command, "Update all nugets in solution")

	utils.update_view(command)
end

return M
