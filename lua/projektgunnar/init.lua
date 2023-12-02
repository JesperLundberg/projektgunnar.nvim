local main = require("projektgunnar.main")
local utils = require("projektgunnar.utils")
local nugets = require("projektgunnar.nugets")

-- add nuget to project
local function AddNugetToProject()
	-- ask user for nuget to add
	local nugetToAdd = vim.fn.input("Nuget to add: ")

	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local projectToAddNugetTo = utils.ask_user_for_project(projects)

	-- add nuget to project
	main.AddOrUpdateNugetsInProject(projectToAddNugetTo, { nugetToAdd })
end

-- update nugets in project
local function UpdateNugetsInProject()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local projectToUpdate = utils.ask_user_for_project(projects)

	-- get all outdated nugets for the selected project
	local outdated_nugets = nugets.outdated_nugets(projectToUpdate)

	-- update nugets in project
	main.AddOrUpdateNugetsInProject(projectToUpdate, outdated_nugets)
end

-- add project to project
local function AddProjectToProject()
	vim.api.nvim_out_write("Select project\n")

	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local projectToAddTo = utils.ask_user_for_project(projects)

	-- remove the project we are adding to from the list of projects to add
	for i, v in ipairs(projects) do
		if v == projectToAddTo then
			table.remove(projects, i)
			break
		end
	end

	vim.api.nvim_out_write("\nSelect project to add to " .. projectToAddTo .. "\n")

	-- get all projects in the solution
	local projectToAdd = utils.ask_user_for_project(projects)

	-- add project to project
	main.AddProjectToProject(projectToAddTo, projectToAdd)
end

vim.api.nvim_create_user_command("AddNugetToProject", AddNugetToProject, { desc = "Add Nuget to Project" })
vim.api.nvim_create_user_command("UpdateNugetsInProject", UpdateNugetsInProject, { desc = "Update Nugets in Project" })
vim.api.nvim_create_user_command(
	"AddProjectToProject",
	AddProjectToProject,
	{ desc = "Add one project as a reference to another" }
)
