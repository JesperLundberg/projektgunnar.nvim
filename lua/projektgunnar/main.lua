local async = require("projektgunnar.async")
local utils = require("projektgunnar.utils")
local nugets = require("projektgunnar.nugets")
local picker = require("projektgunnar.picker")
local notify = require("mini.notify")

-- setup notify and set duration for each level
notify.setup()
vim.notify = notify.make_notify({
	ERROR = { duration = 2000 },
	WARN = { duration = 2000 },
	INFO = { duration = 2000 },
})

local M = {}

-- add nuget to project
function M.AddNugetToProject()
	-- ask user for nuget to add
	local nugetToAdd = vim.fn.input("Nuget to add: ")

	-- if the user did not select a nuget, return
	if nugetToAdd == "" then
		-- vim.api.nvim_err_writeln("No nuget selected")
		vim.notify("No nuget selected", vim.log.levels.ERROR)
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
		vim.notify("No outdated nugets in project " .. choice, vim.log.levels.WARN)
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
	local choice = picker.AskUserForProject(projectsNotInSolution)

	-- add project to solution
	async.AddProjectToSolution(choice)
end

return M
