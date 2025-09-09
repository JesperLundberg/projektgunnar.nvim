local async = require("projektgunnar.async")
local dotnet_jobs = require("projektgunnar.dotnet_jobs")
local utils = require("projektgunnar.utils")
local nugets = require("projektgunnar.nugets")
local picker = require("projektgunnar.picker")
local ui = require("projektgunnar.ui")

local M = {}

-- Add NuGet to a project
function M.add_nuget_to_project()
	-- Ask for the NuGet package first
	ui.input.open(function(nuget_to_add)
		if nuget_to_add == "" then
			vim.notify("No nuget selected", vim.log.levels.ERROR)
			return
		end

		-- Gather all projects
		local projects = utils.get_all_projects_in_solution()
		if #projects == 0 then
			vim.notify("No projects in solution", vim.log.levels.ERROR)
			return
		end

		-- Ask which project to add to
		picker.ask_user_for_choice("Add to", projects, function(choice)
			if not choice then
				vim.notify("No project chosen", vim.log.levels.ERROR)
				return
			end

			local command_and_nuget_to_add = {
				{
					-- dotnet add <project> package <item>
					argv = { "dotnet", "add", choice, "package" },
					items = { nuget_to_add },
				},
			}

			dotnet_jobs.handle_nugets_in_project("Add", command_and_nuget_to_add)
		end)
	end, { title = "Nuget to add" })
end

-- Remove a NuGet from a project (now async to fetch package list)
function M.remove_nuget_from_project()
	local projects = utils.get_all_projects_in_solution()
	if #projects == 0 then
		vim.notify("No projects in solution", vim.log.levels.ERROR)
		return
	end

	-- Pick project first
	picker.ask_user_for_choice("Remove from", projects, function(project_choice)
		if not project_choice then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end

		-- Fetch NuGets in the chosen project asynchronously
		async.run(function()
			local all_pkgs, err = nugets.all_nugets(project_choice)
			if err then
				vim.notify("Failed to list packages: " .. err, vim.log.levels.ERROR)
				return
			end

			if not all_pkgs or #all_pkgs == 0 then
				vim.notify("No nugets in project " .. project_choice, vim.log.levels.WARN)
				return
			end

			-- Pick which NuGet to remove
			picker.ask_user_for_choice("Remove which", all_pkgs, function(nuget_to_remove)
				if not nuget_to_remove then
					vim.notify("No nuget chosen", vim.log.levels.WARN)
					return
				end

				local command_and_nuget_to_remove = {
					{
						-- dotnet remove <project> package <item>
						argv = { "dotnet", "remove", project_choice, "package" },
						items = { nuget_to_remove },
					},
				}

				dotnet_jobs.handle_nugets_in_project("Remove", command_and_nuget_to_remove)
			end)
		end)
	end)
end

-- Update NuGets in a single project (async to compute outdated list)
function M.update_nugets_in_project()
	local projects = utils.get_all_projects_in_solution()
	if #projects == 0 then
		vim.notify("No projects in solution", vim.log.levels.ERROR)
		return
	end

	-- Pick project to update
	picker.ask_user_for_choice("Update project", projects, function(project_choice)
		if not project_choice then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end

		async.run(function()
			local nuget_config_file = utils.get_nuget_config_file()
			local outdated, err = nugets.outdated_nugets(project_choice, nuget_config_file)
			if err then
				vim.notify("Failed to list outdated nugets: " .. err, vim.log.levels.ERROR)
				return
			end

			if not outdated or #outdated == 0 then
				vim.notify("No outdated nugets in project " .. project_choice, vim.log.levels.WARN)
				return
			end

			local command_and_nugets = {
				{
					-- dotnet add <project> package <item>
					argv = { "dotnet", "add", project_choice, "package" },
					items = outdated,
				},
			}

			dotnet_jobs.handle_nugets_in_project("Update", command_and_nugets)
		end)
	end)
end

-- Update all outdated NuGets in the solution (async, sequential)
-- We iterate projects sequentially to avoid hammering dotnet concurrently.
function M.update_nugets_in_solution()
	local projects = utils.get_all_projects_in_solution()
	if #projects == 0 then
		vim.notify("No projects in solution", vim.log.levels.ERROR)
		return
	end

	async.run(function()
		local all_projects_and_nugets = {}
		local nuget_config_file = utils.get_nuget_config_file()

		for i, project in ipairs(projects) do
			vim.notify(("Checking %d / %d: %s"):format(i, #projects, project), vim.log.levels.INFO)

			local outdated, err = nugets.outdated_nugets(project, nuget_config_file)
			if err then
				vim.notify(("Failed to list outdated for %s: %s"):format(project, err), vim.log.levels.ERROR)
			elseif outdated and #outdated > 0 then
				local command_and_nugets = {
					{
						-- dotnet add <project> package <item>
						argv = { "dotnet", "add", project, "package" },
						items = outdated,
					},
				}
				utils.table_concat(all_projects_and_nugets, command_and_nugets)
			else
				vim.notify("No outdated nugets in project " .. project, vim.log.levels.WARN)
			end
		end

		if #all_projects_and_nugets == 0 then
			vim.notify("No outdated nugets in solution", vim.log.levels.WARN)
			return
		end

		dotnet_jobs.handle_nugets_in_project("Update", all_projects_and_nugets)
	end)
end

-- Project references
function M.add_project_reference()
	local projects = utils.get_all_projects_in_solution()
	if #projects == 0 then
		vim.notify("No projects in solution", vim.log.levels.ERROR)
		return
	end

	-- Step 1: pick project to add to
	picker.ask_user_for_choice("Add to", projects, function(project_to_add_to)
		if not project_to_add_to then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end

		-- Remove the chosen project from the list of candidates to reference
		local candidates = {}
		for _, v in ipairs(projects) do
			if v ~= project_to_add_to then
				table.insert(candidates, v)
			end
		end

		if #candidates == 0 then
			vim.notify("No other projects to add as reference", vim.log.levels.WARN)
			return
		end

		-- Step 2: pick which project to reference
		picker.ask_user_for_choice("Add", candidates, function(project_to_reference)
			if not project_to_reference then
				vim.notify("No project chosen", vim.log.levels.ERROR)
				return
			end

			dotnet_jobs.handle_project_reference("add", project_to_add_to, project_to_reference)
		end)
	end)
end

-- Remove project reference from other project
function M.remove_project_reference()
	local projects = utils.get_all_projects_in_solution()
	if #projects == 0 then
		vim.notify("No projects in solution", vim.log.levels.ERROR)
		return
	end

	-- Step 1: pick project to remove from
	picker.ask_user_for_choice("Remove from", projects, function(project_to_remove_from)
		if not project_to_remove_from then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end

		-- Fetch references for that project
		local project_references = utils.get_project_references(project_to_remove_from)
		if #project_references == 0 then
			vim.notify("No project references in " .. project_to_remove_from, vim.log.levels.WARN)
			return
		end

		-- Step 2: pick which reference to remove
		picker.ask_user_for_choice("Remove", project_references, function(reference_choice)
			if not reference_choice then
				vim.notify("No project chosen", vim.log.levels.ERROR)
				return
			end

			dotnet_jobs.handle_project_reference("remove", project_to_remove_from, reference_choice)
		end)
	end)
end

-- Add a project to the solution
function M.add_project_to_solution()
	local all_csproj_files = utils.get_all_projects_in_solution_folder_not_in_solution()
	local projects_in_solution = utils.get_all_projects_in_solution()

	-- Filter to only those not already in the solution
	local projects_not_in_solution = {}
	for _, csproj_file in ipairs(all_csproj_files) do
		if not utils.has_value(projects_in_solution, csproj_file) then
			table.insert(projects_not_in_solution, csproj_file)
		end
	end

	if not projects_not_in_solution or #projects_not_in_solution == 0 then
		vim.notify("No csproj files that are not already in solution", vim.log.levels.WARN)
		return
	end

	picker.ask_user_for_choice("Add", projects_not_in_solution, function(choice)
		if not choice then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end

		dotnet_jobs.add_project_to_solution(choice)
	end)
end

return M
