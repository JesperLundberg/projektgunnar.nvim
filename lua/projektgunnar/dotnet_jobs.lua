local ui = require("projektgunnar.ui")
local async = require("projektgunnar.async")

local api = vim.api
local M = {}

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
			-- High-level progress (which command in the queue)
			async.ui(ui.result.progress, buf, ci, total_commands)

			local base_command = entry.argv or {}
			local items = entry.items or {}
			local total_items = #items

			for ii, item in ipairs(items) do
				-- Build argv per item: copy base and append item
				local argv = vim.deepcopy(base_command)
				table.insert(argv, item)

				-- Start spinner before the long-running command
				ui.result.spinner(buf)

				-- Execute the command and await completion
				local _, _, code = async.system(argv, { text = true })

				-- Stop spinner and clear spinner line
				ui.result.clear_spinner(buf)

				-- Update per-item status in the floating window
				local success = (code == 0)
				local argsToPrint = table.concat(argv or {}, " ")
				async.ui(ui.result.update, buf, ii, total_items, success, argsToPrint)
			end
		end

		-- All commands done
		async.ui(ui.result.done, buf)
	end)
end

--- Add or update nugets in a project/solution
--- @param action string -- e.g. "Adding"/"Updating" (used only for the message)
--- @param command_and_nugets table -- entries with { argv = {...}, items = {...} }
function M.handle_nugets_in_project(action, command_and_nugets)
	local buf = ui.result.open()
	local scope = (#command_and_nugets == 1) and " project" or " solution"

	-- Intro line
	async.ui(ui.result.print, buf, action .. " nugets in" .. scope)

	-- Ensure spinner timer is cleaned up if the result buffer is wiped
	api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			ui.result.clear_spinner(buf)
		end,
	})

	run_queue(buf, command_and_nugets)
end

--- Add or remove a project reference
--- @param action "add"|"remove"
--- @param project_path string
--- @param project_reference_path string
function M.handle_project_reference(action, project_path, project_reference_path)
	local buf = ui.result.open()

	if action == "add" then
		async.ui(ui.result.print, buf, ("Adding project %s to project %s"):format(project_reference_path, project_path))
	else
		async.ui(
			ui.result.print,
			buf,
			("Removing project %s from project %s"):format(project_reference_path, project_path)
		)
	end

	api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			ui.result.clear_spinner(buf)
		end,
	})

	local command_and_project = {
		{ argv = { "dotnet", action, project_path, "reference" }, items = { project_reference_path } },
	}

	run_queue(buf, command_and_project)
end

--- Add a project to the current solution
--- @param sln_path string path to the solution file
--- @param project_to_add_path string path to the project to add
function M.add_project_to_solution(sln_path, project_to_add_path)
	local buf = ui.result.open()

	async.ui(ui.result.print, buf, "Adding project " .. project_to_add_path .. " to solution")

	api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			ui.result.clear_spinner(buf)
		end,
	})

	local command_and_project = {
		{ argv = { "dotnet", "sln", sln_path, "add" }, items = { project_to_add_path } },
	}

	run_queue(buf, command_and_project)
end

return M
