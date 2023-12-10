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

	-- create command and nuget to add table
	local command_and_nuget_to_add =
		{ project = choice, command = "dotnet add " .. choice .. " package ", items = { nugetToAdd } }

	-- add nuget to project
	main.AddOrUpdateNugetsInProject(command_and_nuget_to_add)
end

-- update nugets in project
local function UpdateNugetsInProject()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local choice = picker.AskUserForProject(projects)

	-- get all outdated nugets for the selected project
	local outdated_nugets = nugets.outdated_nugets(choice)

	-- if there are no outdated nugets, notify the user and return
	if #outdated_nugets == 0 then
		print("No outdated nugets in project " .. choice)
		return
	end

	-- create command and nugets to update table
	local command_and_nugets = {
		[1] = { project = choice, command = "dotnet add " .. choice .. " package ", items = outdated_nugets },
	}
	-- update nugets in project
	main.AddOrUpdateNugetsInProject(command_and_nugets)
end

-- local function UpdateNugetsInSolution()
-- 	-- get all projects in the solution
-- 	local projects = utils.get_all_projects_in_solution()
--
-- 	for _, project in ipairs(projects) do
-- 		-- get all outdated nugets for the current project
-- 		local outdated_nugets = nugets.outdated_nugets(project)
--
-- 		-- update nugets in the current project
-- 		main.AddOrUpdateNugetsInProject(project, outdated_nugets)
-- 	end
-- end

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
-- vim.api.nvim_create_user_command(
-- 	"UpdateNugetsInSolution",
-- 	UpdateNugetsInSolution,
-- 	{ desc = "Update Nugets in Solution" }
-- )
vim.api.nvim_create_user_command(
	"AddProjectToProject",
	AddProjectToProject,
	{ desc = "Add one project as a reference to another" }
)
