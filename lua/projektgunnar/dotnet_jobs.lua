local ui = require("projektgunnar.ui")
local async = require("projektgunnar.async")

local api = vim.api
local M = {}

-- How many lines of a failed command's output to show in the result window
local MAX_OUTPUT_LINES = 10

--- Combine stdout and stderr of a command into a list of non-empty lines,
--- keeping only the last MAX_OUTPUT_LINES (that is where dotnet prints the reason).
--- Note: dotnet reports many errors on stdout, so both streams are needed.
--- @param stdout_lines string[]|nil
--- @param stderr string|nil
--- @return string[]
local function tail_output(stdout_lines, stderr)
	local lines = {}

	local function add(line)
		line = vim.trim((line:gsub("\r", "")))
		if line ~= "" then
			lines[#lines + 1] = line
		end
	end

	for _, l in ipairs(stdout_lines or {}) do
		add(l)
	end
	for _, l in ipairs(vim.split(stderr or "", "\n", { trimempty = true })) do
		add(l)
	end

	if #lines > MAX_OUTPUT_LINES then
		return vim.list_slice(lines, #lines - MAX_OUTPUT_LINES + 1, #lines)
	end
	return lines
end

-- Open the result window and make sure its spinner is cleaned up when it closes
--- @return integer buf
local function open_result_window()
	local buf = ui.result.open()

	api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			ui.result.clear_spinner(buf)
		end,
	})

	return buf
end

-- Run a queue of commands sequentially as a linear async flow.
-- Each entry shape:
--   {
--     argv  = { "dotnet", "add", "<project.csproj>", "package" }, -- base argv
--     items = { "Newtonsoft.Json", "Serilog" },                   -- appended one-by-one
--   }
--
-- If the user closes the result window the remaining commands still run (so a
-- half finished update is not left behind), but nothing is drawn any more and a
-- summary is shown with vim.notify when the queue is done.
--- @param buf integer result window buffer
--- @param command_and_items table[]
--- @param intro string|nil first line to print in the result window
local function run_queue(buf, command_and_items, intro)
	async.run(function()
		local function alive()
			return api.nvim_buf_is_valid(buf)
		end

		-- Await a UI function with buf as first argument, unless the window is gone
		local function ui_call(fn, ...)
			if alive() then
				async.ui(fn, buf, ...)
			end
		end

		local total_commands = #command_and_items
		local executed, failed = 0, 0

		if intro then
			ui_call(ui.result.print, intro)
		end

		for ci, entry in ipairs(command_and_items) do
			-- Show which project this entry targets (the path is the third argv: dotnet <verb> <path> ...)
			local target = entry.argv and entry.argv[3]
			local name = target and vim.fn.fnamemodify(target, ":t:r") or nil
			ui_call(ui.result.progress, ci, total_commands, name)

			local base_command = entry.argv or {}
			local items = entry.items or {}
			local total_items = #items

			for ii, item in ipairs(items) do
				-- Build argv per item: copy base and append item
				local argv = vim.deepcopy(base_command)
				table.insert(argv, item)

				-- Start spinner before the long-running command
				if alive() then
					ui.result.spinner(buf)
				end

				-- Execute the command and await completion
				local stdout_lines, stderr, code = async.system(argv, { text = true })

				-- Stop spinner and clear spinner line
				if alive() then
					ui.result.clear_spinner(buf)
				end

				executed = executed + 1
				local success = (code == 0)
				if not success then
					failed = failed + 1
				end

				-- Update per-item status in the floating window
				local argsToPrint = table.concat(argv, " ")
				local output = nil
				if not success then
					output = tail_output(stdout_lines, stderr)
				end
				ui_call(ui.result.update, ii, total_items, success, argsToPrint, item, output)
			end
		end

		-- All commands done
		if alive() then
			async.ui(ui.result.done, buf)
		elseif failed > 0 then
			vim.notify(
				("ProjektGunnar: finished, %d of %d commands failed"):format(failed, executed),
				vim.log.levels.WARN
			)
		else
			vim.notify(("ProjektGunnar: finished, %d commands succeeded"):format(executed), vim.log.levels.INFO)
		end
	end)
end

--- Add, remove or update nugets in a project/solution
--- @param action string -- e.g. "Add"/"Update" (used only for the message)
--- @param command_and_nugets table -- entries with { argv = {...}, items = {...} }
--- @param scope "project"|"solution"|nil -- used only for the message (default "project")
function M.handle_nugets_in_project(action, command_and_nugets, scope)
	local buf = open_result_window()
	run_queue(buf, command_and_nugets, action .. " nugets in " .. (scope or "project"))
end

--- Add or remove a project reference
--- @param action "add"|"remove"
--- @param project_path string
--- @param project_reference_path string
function M.handle_project_reference(action, project_path, project_reference_path)
	local buf = open_result_window()

	local intro
	if action == "add" then
		intro = ("Adding project %s to project %s"):format(project_reference_path, project_path)
	else
		intro = ("Removing project %s from project %s"):format(project_reference_path, project_path)
	end

	local command_and_project = {
		{ argv = { "dotnet", action, project_path, "reference" }, items = { project_reference_path } },
	}

	run_queue(buf, command_and_project, intro)
end

--- Add a project to the current solution
--- @param sln_path string path to the solution file
--- @param project_to_add_path string path to the project to add
function M.add_project_to_solution(sln_path, project_to_add_path)
	local buf = open_result_window()

	local command_and_project = {
		{ argv = { "dotnet", "sln", sln_path, "add" }, items = { project_to_add_path } },
	}

	run_queue(buf, command_and_project, "Adding project " .. project_to_add_path .. " to solution")
end

return M
