local async = require("projektgunnar.async")
local dotnet_jobs = require("projektgunnar.dotnet_jobs")
local utils = require("projektgunnar.utils")
local nugets = require("projektgunnar.nugets")
local picker = require("projektgunnar.picker")
local solution = require("projektgunnar.solution")
local ui = require("projektgunnar.ui")

local M = {}

-- Awaitable wrappers for callback-style APIs that don't fit
-- async.wrap_cb's "callback is the last argument" convention.
local resolve_solution = async.wrap_cb(function(cb)
	solution.resolve(cb)
end)
local ask_choice = async.wrap_cb(function(prompt, items, cb)
	picker.ask_user_for_choice(prompt, items, cb)
end)

-- ui.input.open(cb, opts) takes the callback first, so wrap manually.
local function ask_input(opts)
	return coroutine.yield(function(resume)
		ui.input.open(resume, opts)
	end)
end

-- Add NuGet to a project
function M.add_nuget_to_project()
	async.run(function()
		local sln = resolve_solution()
		if not sln then
			return
		end

		local nuget_to_add = ask_input({ title = "Nuget to add" })
		if not nuget_to_add or nuget_to_add == "" then
			return
		end

		local projects = utils.get_all_projects_in_solution(sln)
		if #projects == 0 then
			vim.notify("No projects in solution", vim.log.levels.ERROR)
			return
		end

		local display_items, by_display = utils.relative_to_cwd(projects)
		assert(by_display)

		local choice = ask_choice("Add NuGet package to", display_items)
		if not choice then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end

		local project_path = by_display[choice]

		local command_and_nuget_to_add = {
			{
				argv = { "dotnet", "add", project_path, "package" },
				items = { nuget_to_add },
			},
		}

		dotnet_jobs.handle_nugets_in_project("Add", command_and_nuget_to_add)
	end)
end

-- Remove a NuGet from a project
function M.remove_nuget_from_project()
	async.run(function()
		local sln = resolve_solution()
		if not sln then
			return
		end

		local projects = utils.get_all_projects_in_solution(sln)
		if #projects == 0 then
			vim.notify("No projects in solution", vim.log.levels.ERROR)
			return
		end
		local display_items, by_display = utils.relative_to_cwd(projects)
		assert(by_display)

		local project_choice = ask_choice("Remove from", display_items)
		if not project_choice then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end

		local project_path = by_display[project_choice]

		local all_pkgs, err = nugets.all_nugets(project_path)
		if err then
			vim.notify("Failed to list packages: " .. err, vim.log.levels.ERROR)
			return
		end

		if not all_pkgs or #all_pkgs == 0 then
			vim.notify("No nugets in project " .. project_choice, vim.log.levels.WARN)
			return
		end

		local nuget_to_remove = ask_choice("Remove which", all_pkgs)
		if not nuget_to_remove then
			vim.notify("No nuget chosen", vim.log.levels.WARN)
			return
		end

		local command_and_nuget_to_remove = {
			{
				argv = { "dotnet", "remove", project_path, "package" },
				items = { nuget_to_remove },
			},
		}

		dotnet_jobs.handle_nugets_in_project("Remove", command_and_nuget_to_remove)
	end)
end

-- Update nugets
function M.update_nugets_in_project()
	async.run(function()
		local sln = resolve_solution()
		if not sln then
			return
		end

		local projects = utils.get_all_projects_in_solution(sln)
		if #projects == 0 then
			vim.notify("No projects in solution", vim.log.levels.ERROR)
			return
		end

		local display_items, by_display = utils.relative_to_cwd(projects)
		assert(by_display)

		local project_choice = ask_choice("Update project", display_items)
		if not project_choice then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end

		local project_path = by_display[project_choice]

		local nuget_config_file = utils.get_nuget_config_file()
		local outdated, err = nugets.outdated_nugets(project_path, nuget_config_file)
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
				argv = { "dotnet", "add", project_path, "package" },
				items = outdated,
			},
		}

		dotnet_jobs.handle_nugets_in_project("Update", command_and_nugets)
	end)
end

function M.update_nugets_in_solution()
	async.run(function()
		local sln = resolve_solution()
		if not sln then
			return
		end

		local projects = utils.get_all_projects_in_solution(sln)
		if #projects == 0 then
			vim.notify("No projects in solution", vim.log.levels.ERROR)
			return
		end

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
	async.run(function()
		local sln = resolve_solution()
		if not sln then
			return
		end

		local projects = utils.get_all_projects_in_solution(sln)
		if #projects == 0 then
			vim.notify("No projects in solution", vim.log.levels.ERROR)
			return
		end

		local display_items, by_display = utils.relative_to_cwd(projects)
		assert(by_display)

		-- Step 1: pick project to add to
		local add_to_choice = ask_choice("Add to", display_items)
		if not add_to_choice then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end
		local project_to_add_to = by_display[add_to_choice]

		-- Remove the chosen project from the list of candidates to reference
		local candidate_display_items = {}
		for _, display in ipairs(display_items) do
			if display ~= add_to_choice then
				table.insert(candidate_display_items, display)
			end
		end

		if #candidate_display_items == 0 then
			vim.notify("No other projects to add as reference", vim.log.levels.WARN)
			return
		end

		-- Step 2: pick which project to reference
		local reference_choice = ask_choice("Add", candidate_display_items)
		if not reference_choice then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end
		local project_to_reference = by_display[reference_choice]

		dotnet_jobs.handle_project_reference("add", project_to_add_to, project_to_reference)
	end)
end

-- Remove project reference from other project
function M.remove_project_reference()
	async.run(function()
		local sln = resolve_solution()
		if not sln then
			return
		end

		local projects = utils.get_all_projects_in_solution(sln)
		if #projects == 0 then
			vim.notify("No projects in solution", vim.log.levels.ERROR)
			return
		end

		local display_items, by_display = utils.relative_to_cwd(projects)
		assert(by_display)

		-- Step 1: pick project to remove from
		local remove_from_choice = ask_choice("Remove from", display_items)
		if not remove_from_choice then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end
		local project_to_remove_from = by_display[remove_from_choice]

		-- Fetch references for that project
		local project_references = utils.get_project_references(project_to_remove_from)
		if not project_references or #project_references == 0 then
			vim.notify("No project references in " .. remove_from_choice, vim.log.levels.WARN)
			return
		end

		local ref_display_items, ref_by_display = utils.relative_to_cwd(project_references)
		assert(ref_by_display)

		-- Step 2: pick which reference to remove
		local reference_choice = ask_choice("Remove", ref_display_items)
		if not reference_choice then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end
		local reference_to_remove = ref_by_display[reference_choice]

		dotnet_jobs.handle_project_reference("remove", project_to_remove_from, reference_to_remove)
	end)
end

-- Add a project to the solution
function M.add_project_to_solution()
	async.run(function()
		local sln = resolve_solution()
		if not sln then
			return
		end

		local all_csproj_files = utils.get_all_project_files()
		local projects_in_solution = utils.get_all_projects_in_solution(sln)

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

		local display_items, by_display = utils.relative_to_cwd(projects_not_in_solution)
		assert(by_display)

		local choice = ask_choice("Add", display_items)
		if not choice then
			vim.notify("No project chosen", vim.log.levels.ERROR)
			return
		end
		local project_path = by_display[choice]

		dotnet_jobs.add_project_to_solution(sln, project_path)
	end)
end

return M
