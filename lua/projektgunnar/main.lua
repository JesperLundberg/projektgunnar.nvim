local async = require("projektgunnar.async")
local utils = require("projektgunnar.utils")
local nugets = require("projektgunnar.nugets")
local picker = require("projektgunnar.picker")
local input_window = require("projektgunnar.input_window")

local M = {}

--- add nuget to project
function M.add_nuget_to_project()
	-- ask user for nuget to add (using callback method to ensure correct order of execution)
	input_window.input_window(function(nuget_to_add)
		-- if the user did not select a nuget, return
		if nuget_to_add == "" then
			vim.notify("No nuget selected", vim.log.levels.ERROR)
			return
		end

		-- get all projects in the solution
		local projects = utils.get_all_projects_in_solution()

		-- If there are no projects in the solution, notify the user and return
		if #projects == 0 then
			vim.notify("No projects in solution", vim.log.levels.ERROR)
			return
		end

		-- ask user for project to add nuget to
		local choice = picker.ask_user_for_choice("Add to", projects)

		-- if the user did not select a project, return
		if not choice then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end

		-- create command and nuget to add table
		local command_and_nuget_to_add = {
			[1] = { project = choice, command = "dotnet add " .. choice .. " package ", items = { nuget_to_add } },
		}

		-- add nuget to project
		async.handle_nugets_in_project("Add", command_and_nuget_to_add)
	end, { title = "Nuget to add" })
end

--- remove nuget from project
function M.remove_nuget_from_project()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()

	-- If there are no projects in the solution, notify the user and return
	if #projects == 0 then
		vim.notify("No projects in solution", vim.log.levels.ERROR)
		return
	end

	-- ask user for project to add nuget to
	local choice = picker.ask_user_for_choice("Remove from", projects)

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
	local nuget_to_remove = picker.ask_user_for_choice("Remove which", all_nugets)

	-- if the user did not select a nuget, return
	if not nuget_to_remove then
		vim.notify("No nuget chosen", vim.log.levels.WARN)
		return
	end

	-- create command and nuget to remove table
	local command_and_nuget_to_remove = {
		[1] = { project = choice, command = "dotnet remove " .. choice .. " package ", items = { nuget_to_remove } },
	}

	-- remove nuget from project
	async.handle_nugets_in_project("Remove", command_and_nuget_to_remove)
end

--- update nugets in project
function M.update_nugets_in_project()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()
	local choice = picker.ask_user_for_choice("Update project", projects)

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
	async.handle_nugets_in_project("Update", command_and_nugets)
end

--- update all nugets in the solution
function M.update_nugets_in_solution()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()

	local all_projects_and_nugets = {}

	for i, project in ipairs(projects) do
		-- get all outdated nugets for the selected project
		local outdated_nugets = nugets.all_outdated_nugets_in_solution()

		vim.notify("Checking " .. i .. " out of " .. #projects .. " projects", vim.log.levels.INFO)

		-- if there are no outdated nugets, notify the user and return
		if #outdated_nugets == 0 then
			vim.notify("No outdated nugets in project " .. project, vim.log.levels.WARN)
			goto continue
		end

		-- get all nugets for the selected project and only keep the ones that are actually IN the project
		-- this is done to avoid adding nugets that are not in the project to the project
		local all_nugets = nugets.all_nugets(project)
		local outdated_nugets_in_project = {}

		-- loop through all outdated nugets and only keep the ones that are in the project
		for _, nuget in ipairs(outdated_nugets) do
			if utils.has_value(all_nugets, nuget) then
				table.insert(outdated_nugets_in_project, nuget)
			end
		end

		-- create command and nugets to update table
		local command_and_nugets = {
			[1] = {
				project = project,
				command = "dotnet add " .. project .. " package ",
				items = outdated_nugets_in_project,
			},
		}

		-- update nugets in project
		utils.table_concat(all_projects_and_nugets, command_and_nugets)

		::continue::
	end

	-- if there are no outdated nugets, notify the user and return
	if #all_projects_and_nugets == 0 then
		vim.notify("No outdated nugets in solution", vim.log.levels.WARN)
		return
	end

	async.handle_nugets_in_project("Update", all_projects_and_nugets)
end

--- Function to add or remove project reference
function M.add_project_reference()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()

	-- If there are no projects in the solution, notify the user and return
	if #projects == 0 then
		vim.notify("No projects in solution", vim.log.levels.ERROR)
		return
	end

	local choice = picker.ask_user_for_choice("Add to", projects)
	local project_to_add_to = choice

	-- if the user did not select a project, return
	if not choice then
		vim.notify("No project chosen", vim.log.levels.ERROR)
		return
	end

	-- remove the project we are adding to from the list of projects to add
	for i, v in ipairs(projects) do
		if v == project_to_add_to then
			table.remove(projects, i)
			break
		end
	end

	-- ask user for project to add
	choice = picker.ask_user_for_choice("Add", projects)

	-- if the user did not select a project, return
	if not choice then
		vim.notify("No project chosen", vim.log.levels.ERROR)
		return
	end

	-- add project to project
	async.handle_project_reference("add", project_to_add_to, choice)
end

--- remove project from project
function M.remove_project_reference()
	-- get all projects in the solution
	local projects = utils.get_all_projects_in_solution()

	-- If there are no projects in the solution, notify the user and return
	if #projects == 0 then
		vim.notify("No projects in solution", vim.log.levels.ERROR)
		return
	end

	local choice = picker.ask_user_for_choice("Remove from", projects)
	local project_to_remove_from = choice

	-- if the user did not select a project, return
	if not choice then
		vim.notify("No project chosen", vim.log.levels.ERROR)
		return
	end

	-- get all project references for the selected project
	local project_references = utils.get_project_references(project_to_remove_from)

	-- ask user for project to remove
	choice = picker.ask_user_for_choice("Remove", project_references)

	-- if the user did not select a project, return
	if not choice then
		vim.notify("No project chosen", vim.log.levels.ERROR)
		return
	end

	-- remove project from project
	async.handle_project_reference("remove", project_to_remove_from, choice)
end

--- add project to solution
function M.add_project_to_solution()
	-- get all projects in the solution folder and in the solution respectively
	local all_csproj_files = utils.get_all_projects_in_solution_folder_not_in_solution()
	local projects_in_solution = utils.get_all_projects_in_solution()

	local projects_not_in_solution = {}

	-- find all csproj files that are not in the solution
	for _, csproj_file in ipairs(all_csproj_files) do
		if not utils.has_value(projects_in_solution, csproj_file) then
			table.insert(projects_not_in_solution, csproj_file)
		end
	end

	if not projects_not_in_solution then
		vim.notify("No csproj files that are not already in solution", vim.log.levels.WARN)
		return
	end

	-- ask user for project to add to solution
	local choice = picker.ask_user_for_choice("Add", projects_not_in_solution)

	-- if the user did not select a project, return
	if not choice then
		vim.notify("No project chosen", vim.log.levels.ERROR)
		return
	end

	-- add project to solution
	async.add_project_to_solution(choice)
end

return M
