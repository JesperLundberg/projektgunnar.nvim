local picker = require("mini.pick")

local M = {}

local chosen_project = nil

function M.AskUserForProject(projects)
	picker.ui_select(projects, {}, function(choice)
		chosen_project = choice
	end)

	return chosen_project
end

return M
