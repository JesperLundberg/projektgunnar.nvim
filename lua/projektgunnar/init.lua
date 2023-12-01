local main = require("projektgunnar.main")
local utils = require("projektgunnar.utils")
local nugets = require("projektgunnar.nugets")

local function UpdateNugetsInProject()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local projectToUpdate = projects[vim.fn.inputlist(projects)]

	-- get all outdated nugets for the selected project
	local outdated_nugets = nugets.outdated_nugets(projectToUpdate)

	-- update nugets in project
	main.UpdateNugetsInProject(projectToUpdate, outdated_nugets)
end

vim.api.nvim_create_user_command("UpdateNugetsInProject", UpdateNugetsInProject, { desc = "Update Nugets in Project" })
