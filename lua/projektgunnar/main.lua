local async = require("projektgunnar.async")
local utils = require("projektgunnar.utils")
local nugets = require("projektgunnar.nugets")
local picker = require("projektgunnar.picker")

local M = {}

-- add nuget to project
function M.AddNugetToProject()
	-- ask user for nuget to add
	local nugetToAdd = vim.fn.input("Nuget to add: ")

	-- if the user did not select a nuget, return
	if nugetToAdd == "" then
		vim.api.nvim_err_writeln("No nuget selected")

		return
	end

	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local choice = picker.AskUserForProject(projects)

	-- if the user did not select a project, return
	if not choice then
		return
	end

	-- create command and nuget to add table
	local command_and_nuget_to_add = {
		[1] = { project = choice, command = "dotnet add " .. choice .. " package ", items = { nugetToAdd } },
	}

	-- add nuget to project
	async.AddOrUpdateNugetsInProject(command_and_nuget_to_add)
end

-- update nugets in project
function M.UpdateNugetsInProject()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local choice = picker.AskUserForProject(projects)

	-- if the user did not select a project, return
	if not choice then
		return
	end

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
	async.AddOrUpdateNugetsInProject(command_and_nugets)
end

function M.UpdateNugetsInSolution()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()

	local all_projects_and_nugets = {}

	for i, project in ipairs(projects) do
		-- get all outdated nugets for the selected project
		local outdated_nugets = nugets.outdated_nugets(project)

		print("Checking " .. i .. " out of " .. #projects .. " projects")

		-- if there are no outdated nugets, notify the user and return
		if #outdated_nugets == 0 then
			goto continue
		end

		-- create command and nugets to update table
		local command_and_nugets = {
			[1] = { project = project, command = "dotnet add " .. project .. " package ", items = outdated_nugets },
		}

		-- update nugets in project
		utils.table_concat(all_projects_and_nugets, command_and_nugets)

		::continue::
	end

	async.AddOrUpdateNugetsInProject(all_projects_and_nugets)
end

-- add project to project
function M.AddProjectToProject()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local choice = picker.AskUserForProject(projects)
	local projectToAddTo = choice

	-- if the user did not select a project, return
	if not choice then
		return
	end

	-- remove the project we are adding to from the list of projects to add
	for i, v in ipairs(projects) do
		if v == projectToAddTo then
			table.remove(projects, i)
			break
		end
	end

	-- ask user for project to add
	choice = picker.AskUserForProject(projects)

	-- if the user did not select a project, return
	if not choice then
		return
	end

	-- add project to project
	async.AddProjectToProject(projectToAddTo, choice)
end

return M
