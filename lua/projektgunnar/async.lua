local floating_window = require("projektgunnar.floating_window")

local M = {}

-- Helper: schedule UI-affecting calls so they don't run in a fast event context
local function ui(fn, ...)
	local args = { ... }
	vim.schedule(function()
		-- pcall to avoid cascading errors if buffer was closed etc.
		pcall(fn, unpack(args))
	end)
end

-- Run a queue of commands sequentially (no coroutines).
-- command_and_items: {
--   { command = "dotnet add <proj> package ", items = { "PkgA", "PkgB" } },
--   { command = "dotnet add <proj> package ", items = { "PkgC" } },
-- }
local function run_queue(buf, command_and_items)
	local total_commands = #command_and_items
	local ci, ii = 1, 0 -- command index, item index

	local function step()
		local entry = command_and_items[ci]
		if not entry then
			-- All commands are done
			ui(floating_window.update_with_done_message, buf)
			return
		end

		-- Starting a new command group? Update header/progress
		if ii == 0 then
			ui(floating_window.update_progress, buf, ci, total_commands)
		end

		ii = ii + 1
		local item = entry.items[ii]

		-- End of this group → move to the next group
		if not item then
			ci = ci + 1
			ii = 0
			vim.schedule(step)
			return
		end

		local cmd = entry.command .. item

		-- Run command asynchronously; callback executes when the process exits
		vim.system({ "sh", "-c", cmd }, { text = true }, function(result)
			local success = (result.code == 0)
			local total_items = #entry.items

			-- Schedule UI update to run in the UI thread
			ui(floating_window.update, buf, ii, total_items, success, cmd)

			-- Continue with the next item/group
			vim.schedule(step)
		end)
	end

	step()
end

--- Add or update nugets in a project/solution
--- @param action string -- e.g. "Adding"/"Updating" (used only for the message)
--- @param command_and_nugets table
function M.handle_nugets_in_project(action, command_and_nugets)
	local buf = floating_window.open()

	local project_or_solution = (#command_and_nugets == 1) and " project" or " solution"
	ui(floating_window.print_message, buf, action .. " nugets in" .. project_or_solution)

	run_queue(buf, command_and_nugets)
end

--- Add or remove a project reference
--- @param action string -- "add" or "remove"
--- @param project_path string
--- @param project_reference_path string
function M.handle_project_reference(action, project_path, project_reference_path)
	local buf = floating_window.open()

	if action == "add" then
		ui(
			floating_window.print_message,
			buf,
			"Adding project " .. project_reference_path .. " to project " .. project_path
		)
	else
		ui(
			floating_window.print_message,
			buf,
			"Removing project " .. project_reference_path .. " from project " .. project_path
		)
	end

	local command_and_project = {
		{
			command = "dotnet " .. action .. " " .. project_path .. " reference ",
			items = { project_reference_path },
		},
	}

	run_queue(buf, command_and_project)
end

--- Add a project to the current solution
--- @param project_to_add_path string
function M.add_project_to_solution(project_to_add_path)
	local buf = floating_window.open()

	ui(floating_window.print_message, buf, "Adding project " .. project_to_add_path .. " to solution")

	local command_and_project = {
		{ command = "dotnet sln add ", items = { project_to_add_path } },
	}

	run_queue(buf, command_and_project)
end

return M
