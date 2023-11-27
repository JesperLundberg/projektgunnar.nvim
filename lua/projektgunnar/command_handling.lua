local nugets = require("projektgunnar.nugets")
local utils = require("projektgunnar.utils")

local M = {}

M.previous_line = nil

function M.run_command_under_cursor()
	local line = vim.api.nvim_get_current_line()
	line = vim.trim(line)

	-- echo line and previous line
	vim.cmd("echo '" .. line .. "'")
	if M.previous_line ~= nil then
		vim.cmd("echo '" .. M.previous_line .. "'")
	end

	if M.previous_line == nil and line == "Update all nugets in project" then
		M.previous_line = line -- TODO: Does this work if we run the plugin twice?
		local all_projects = utils.get_all_projects_in_solution()
		utils.update_view(all_projects)

	-- TODO: Need to reset last_command each time we're done?
	elseif line == "Update all nugets in solution" then
		-- echo "Updating all nugets in solution"
		vim.cmd("echo 'Updating all nugets in solution'")
		-- nugets.update_packages_in_solution()
	end

	-- if line contains / then it's a project
	if string.find(line, "/") then
		local outdated_nugets = nugets.outdated_nugets(line)
		utils.update_view(outdated_nugets)
		nugets.update_packages_in_project(line, outdated_nugets)
	end
end

return M
