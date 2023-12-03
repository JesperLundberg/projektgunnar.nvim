local picker = require("mini.pick")

local M = {}

function M.AskUserForProject(projects)
	picker.ui_select(projects, {}, function(choice)
		M.choice = choice
	end)
end

return M
