local main = require("projektgunnar.main")

local M = {}
local L = {}

function L.get_all_projects_in_solution()
	-- run the dotnet command from the root of the project using solution file got get all available projects
	local output = vim.fn.systemlist("dotnet sln list")

	-- remove the first two lines from the output
	local projects = vim.list_slice(output, 3, #output)

	return projects
end

function L.outdated_nugets(project)
	-- run the outdated nugets command for the selected project
	local outdated_nugets = vim.fn.systemlist("dotnet list " .. project .. " package --outdated  | awk '/>/{print $2}'")

	return outdated_nugets
end

function L.UpdateNugetsInProject()
	-- get all projects in the solution
	local projects = L.get_all_projects_in_solution()
	local projectToUpdate = projects[vim.fn.inputlist(projects)]

	-- get all outdated nugets for the selected project
	local outdated_nugets = L.outdated_nugets(projectToUpdate)

	main.UpdateNugetsInProject(projectToUpdate, outdated_nugets)
end

vim.api.nvim_create_user_command(
	"UpdateNugetsInProject",
	L.UpdateNugetsInProject,
	{ desc = "Update Nugets in Project" }
)

return M
