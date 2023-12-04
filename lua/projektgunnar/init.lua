local main = require("projektgunnar.main")
local utils = require("projektgunnar.utils")
local nugets = require("projektgunnar.nugets")
local picker = require("projektgunnar.picker")

-- add nuget to project
local function AddNugetToProject()
	-- ask user for nuget to add
	local nugetToAdd = vim.fn.input("Nuget to add: ")

	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local choice = picker.AskUserForProject(projects)

	-- add nuget to project
	main.AddOrUpdateNugetsInProject(choice, { nugetToAdd })
end

-- update nugets in project
local function UpdateNugetsInProject()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local choice = picker.AskUserForProject(projects)

	-- get all outdated nugets for the selected project
	local outdated_nugets = nugets.outdated_nugets(choice)

	-- update nugets in project
	main.AddOrUpdateNugetsInProject(choice, outdated_nugets)
end

-- add project to project
local function AddProjectToProject()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local choice = picker.AskUserForProject(projects)
	local projectToAddTo = choice

	-- remove the project we are adding to from the list of projects to add
	for i, v in ipairs(projects) do
		if v == projectToAddTo then
			table.remove(projects, i)
			break
		end
	end

	-- ask user for project to add
	choice = picker.AskUserForProject(projects)

	-- add project to project
	main.AddProjectToProject(projectToAddTo, choice)
end

vim.api.nvim_create_user_command("AddNugetToProject", AddNugetToProject, { desc = "Add Nuget to Project" })
vim.api.nvim_create_user_command("UpdateNugetsInProject", UpdateNugetsInProject, { desc = "Update Nugets in Project" })
vim.api.nvim_create_user_command(
	"AddProjectToProject",
	AddProjectToProject,
	{ desc = "Add one project as a reference to another" }
)
