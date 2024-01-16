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
		vim.notify("No nuget selected", vim.log.levels.ERROR)
		return
	end

	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local choice = picker.AskUserForChoice(projects)

	-- if the user did not select a project, return
	if not choice then
		vim.notify("No project chosen", vim.log.levels.ERROR)
		return
	end

	-- create command and nuget to add table
	local command_and_nuget_to_add = {
		[1] = { project = choice, command = "dotnet add " .. choice .. " package ", items = { nugetToAdd } },
	}

	-- add nuget to project
	async.HandleNugetsInProject("Add", command_and_nuget_to_add)
end

-- remove nuget from project
function M.RemoveNugetFromProject()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local choice = picker.AskUserForChoice(projects)

	-- if the user did not select a project, return
	if not choice then
		vim.notify("No project chosen", vim.log.levels.ERROR)
		return
	end

	-- get all nugets for the selected project
	local all_nugets = nugets.all_nugets(choice)

	-- if there are no nugets, notify the user and return
	if #all_nugets == 0 then
		vim.notify("No nugets in project " .. choice, vim.log.levels.WARN)
		return
	end

	-- ask user for nuget to remove
	local nugetToRemove = picker.AskUserForChoice(all_nugets)

	-- if the user did not select a nuget, return
	if not nugetToRemove then
		vim.notify("No nuget chosen", vim.log.levels.WARN)
		return
	end

	-- create command and nuget to remove table
	local command_and_nuget_to_remove = {
		[1] = { project = choice, command = "dotnet remove " .. choice .. " package ", items = { nugetToRemove } },
	}

	-- remove nuget from project
	async.HandleNugetsInProject("Remove", command_and_nuget_to_remove)
end

-- update nugets in project
function M.UpdateNugetsInProject()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local choice = picker.AskUserForChoice(projects)

	-- if the user did not select a project, return
	if not choice then
		vim.notify("No project chosen", vim.log.levels.ERROR)
		return
	end

	-- get all outdated nugets for the selected project
	local outdated_nugets = nugets.outdated_nugets(choice)

	-- if there are no outdated nugets, notify the user and return
	if #outdated_nugets == 0 then
		vim.notify("No outdated nugets in project " .. choice, vim.log.levels.WARN)
		return
	end

	-- create command and nugets to update table
	local command_and_nugets = {
		[1] = { project = choice, command = "dotnet add " .. choice .. " package ", items = outdated_nugets },
	}
	-- update nugets in project
	async.HandleNugetsInProject("Update", command_and_nugets)
end

function M.UpdateNugetsInSolution()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()

	local all_projects_and_nugets = {}

	for i, project in ipairs(projects) do
		-- get all outdated nugets for the selected project
		local outdated_nugets = nugets.outdated_nugets(project)

		vim.notify("Checking " .. i .. " out of " .. #projects .. " projects", vim.log.levels.INFO)

		-- if there are no outdated nugets, notify the user and return
		if #outdated_nugets == 0 then
			vim.notify("No outdated nugets in project " .. project, vim.log.levels.WARN)
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

	async.HandleNugetsInProject("Update", all_projects_and_nugets)
end

-- Function to add or remove project reference
function M.AddProjectReference()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local choice = picker.AskUserForChoice(projects)
	local projectToAddTo = choice

	-- if the user did not select a project, return
	if not choice then
		vim.notify("No project chosen", vim.log.levels.ERROR)
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
	choice = picker.AskUserForChoice(projects)

	-- if the user did not select a project, return
	if not choice then
		vim.notify("No project chosen", vim.log.levels.ERROR)
		return
	end

	-- add project to project
	async.HandleProjectReference("add", projectToAddTo, choice)
end

-- remove project from project
function M.RemoveProjectReference()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local choice = picker.AskUserForChoice(projects)
	local projectToRemoveFrom = choice

	-- if the user did not select a project, return
	if not choice then
		vim.notify("No project chosen", vim.log.levels.ERROR)
		return
	end

	-- get all project references for the selected project
	local project_references = utils.get_project_references(projectToRemoveFrom)

	print(vim.inspect(project_references))

	-- ask user for project to remove
	choice = picker.AskUserForChoice(project_references)

	-- if the user did not select a project, return
	if not choice then
		vim.notify("No project chosen", vim.log.levels.ERROR)
		return
	end

	-- remove project from project
	async.HandleProjectReference("remove", projectToRemoveFrom, choice)
end

-- add project to solution
function M.AddProjectToSolution()
	-- get all projects in the solution folder and in the solution respectively
	local allCsprojFiles = utils.get_all_projects_in_solution_folder_not_in_solution()
	local projectsInSolution = utils.get_all_projects_in_solution()

	local projectsNotInSolution = {}

	-- find all csproj files that are not in the solution
	for _, csprojFile in ipairs(allCsprojFiles) do
		if not utils.has_value(projectsInSolution, csprojFile) then
			table.insert(projectsNotInSolution, csprojFile)
		end
	end

	-- ask user for project to add to solution
	local choice = picker.AskUserForChoice(projectsNotInSolution)

	-- if the user did not select a project, return
	if not choice then
		vim.notify("No project chosen", vim.log.levels.ERROR)
		return
	end

	-- add project to solution
	async.AddProjectToSolution(choice)
end

return M
