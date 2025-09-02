-- lua/projektgunnar/dotnet_jobs.lua
-- Domain-specific runner for dotnet commands with floating window progress.
-- Now using a linear coroutine flow via projektgunnar.async.

local floating_window = require("projektgunnar.floating_window")
local async = require("projektgunnar.async")

local M = {}

-- Build a readable command string from argv for UI/logging
local function to_display_cmd(argv)
	return table.concat(argv or {}, " ")
end

-- Run a queue of commands sequentially as a linear async flow.
-- Each entry shape:
--   {
--     argv  = { "dotnet", "add", "<project.csproj>", "package" }, -- base argv
--     items = { "Newtonsoft.Json", "Serilog" },                   -- appended one-by-one
--   }
local function run_queue(buf, command_and_items)
	async.run(function()
		local total_commands = #command_and_items

		for ci, entry in ipairs(command_and_items) do
			-- Update high-level progress (which command in the queue)
			async.ui(floating_window.update_progress, buf, ci, total_commands)

			local base = entry.argv or {}
			local items = entry.items or {}
			local total_items = #items

			for ii, item in ipairs(items) do
				-- Build argv per item: copy base and append item
				local argv = vim.deepcopy(base)
				table.insert(argv, item)

				-- Execute the command and await completion
				local _, stderr, code = async.system(argv, { text = true })

				-- Update per-item status in the floating window
				local success = (code == 0)
				async.ui(floating_window.update, buf, ii, total_items, success, to_display_cmd(argv))
			end
		end

		-- All commands done
		async.ui(floating_window.update_with_done_message, buf)
	end)
end

--- Add or update nugets in a project/solution
--- @param action string -- e.g. "Adding"/"Updating" (used only for the message)
--- @param command_and_nugets table -- entries with { argv = {...}, items = {...} }
function M.handle_nugets_in_project(action, command_and_nugets)
	local buf = floating_window.open()
	local scope = (#command_and_nugets == 1) and " project" or " solution"

	async.ui(floating_window.print_message, buf, action .. " nugets in" .. scope)

	run_queue(buf, command_and_nugets)
end

--- Add or remove a project reference
--- @param action "add"|"remove"
--- @param project_path string
--- @param project_reference_path string
function M.handle_project_reference(action, project_path, project_reference_path)
	local buf = floating_window.open()

	if action == "add" then
		async.ui(
			floating_window.print_message,
			buf,
			"Adding project " .. project_reference_path .. " to project " .. project_path
		)
	else
		async.ui(
			floating_window.print_message,
			buf,
			"Removing project " .. project_reference_path .. " from project " .. project_path
		)
	end

	local command_and_project = {
		{
			argv = { "dotnet", action, project_path, "reference" },
			items = { project_reference_path },
		},
	}

	run_queue(buf, command_and_project)
end

--- Add a project to the current solution
--- @param project_to_add_path string
function M.add_project_to_solution(project_to_add_path)
	local buf = floating_window.open()

	async.ui(floating_window.print_message, buf, "Adding project " .. project_to_add_path .. " to solution")

	local command_and_project = {
		{
			argv = { "dotnet", "sln", "add" },
			items = { project_to_add_path },
		},
	}

	run_queue(buf, command_and_project)
end

return M
