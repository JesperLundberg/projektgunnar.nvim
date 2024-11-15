local floating_window = require("projektgunnar.floating_window")

local M = {}

local async_task

--- Function to reset and clean up the async task after each run
local function reset_and_cleanup()
	-- Stop the coroutine if it's running
	if async_task and coroutine.status(async_task) == "running" then
		coroutine.yield()
	end

	-- Reset the async task
	async_task = nil
end

--- Coroutine function to perform asynchronous task
--- @param command_and_items table
--- @param buf number
local function create_async_task(command_and_items, buf)
	return coroutine.create(function()
		-- loop through the command and item table
		for commandIndex, command_and_item in ipairs(command_and_items) do
			-- assert command and nugets variables so they are not nil
			assert(command_and_item.command, "command_and_item.command is nil")
			assert(command_and_item.items, "command_and_item.items is nil")

			local total_commands = #command_and_items
			local total_nugets = #command_and_item.items
			local captured_lines = {}

			-- Print progress
			floating_window.update_progress(buf, commandIndex, total_commands)

			-- Loop through all nugets and update them
			for nugetIndex, item_to_add in ipairs(command_and_item.items) do
				-- Construct the dotnet command
				local dotnet_command = command_and_item.command .. item_to_add

				-- Initialize success
				local success = false

				-- Start an external command as a job (non-blocking)
				vim.fn.jobstart(dotnet_command, {
					on_stdout = function(_, data)
						for _, line in ipairs(data) do
							table.insert(captured_lines, line)
							floating_window.progress_spinner(buf)
						end
					end,
					on_exit = function(_, code)
						-- Check the exit code if needed
						if code == 0 then
							-- Update buffer lines with the current iteration (success)
							success = true
						end

						-- Clear the spinner if it exists
						floating_window.clear_spinner(buf)

						-- Update buffer with success/failure information
						floating_window.update(buf, nugetIndex, total_nugets, success, dotnet_command)

						-- Resume the coroutine for the next iteration
						coroutine.resume(async_task, buf)
					end,
				})

				-- Suspend the coroutine until the job exit callback is executed
				coroutine.yield()
			end

			-- when all work is done, update the floating window with a done message
			if #command_and_items == commandIndex then
				floating_window.update_with_done_message(buf)
			end
		end
		-- After all iterations are complete, reset and clean up
		M.reset_and_cleanup()
	end)
end

--- Function to add or update nugets in/to project
--- @param action string
--- @param command_and_nugets table
function M.handle_nugets_in_project(action, command_and_nugets)
	-- Open a floating window and get handles
	local buf = floating_window.open()

	-- If there is only one command and nugets, it is a project, otherwise it is a solution
	local project_or_solution = #command_and_nugets == 1 and " project" or " solution"

	-- Notify the user that the command will add or update nugets
	floating_window.print_message(buf, action .. " nugets in" .. project_or_solution)

	-- Reset and cleanup from previous run
	reset_and_cleanup()

	-- Create a new coroutine for the current run
	async_task = create_async_task(command_and_nugets, buf)

	-- Start the coroutine with the floating window handles
	coroutine.resume(async_task, buf)
end

--- Function to add project to project
--- @param action string
--- @param project_path string
--- @param project_reference_path string
function M.handle_project_reference(action, project_path, project_reference_path)
	-- Open a floating window and get handles
	local buf = floating_window.open()

	-- Notify the user that the command either add or remove project reference
	if action == "add" then
		floating_window.print_message(
			buf,
			"Adding project " .. project_reference_path .. " to project " .. project_path
		)
	else
		floating_window.print_message(
			buf,
			"Removing project " .. project_reference_path .. " from project " .. project_path
		)
	end

	-- Reset and cleanup from previous run
	reset_and_cleanup()

	local command_and_project = {
		[1] = {
			command = "dotnet " .. action .. " " .. project_path .. " reference ",
			items = {
				project_reference_path,
			},
		},
	}

	-- Create a new coroutine for the current run
	async_task = create_async_task(command_and_project, buf)

	-- Start the coroutine with the floating window handles
	coroutine.resume(async_task, buf)
end

--- Function to add project to solution
--- @param project_to_add_path string
function M.add_project_to_solution(project_to_add_path)
	-- Open a floating window and get handles
	local buf = floating_window.open()

	-- Notify the user that the command will add project to project
	floating_window.print_message(buf, "Adding project " .. project_to_add_path .. " to solution")

	-- Reset and cleanup from previous run
	reset_and_cleanup()

	local command_and_project = {
		[1] = { command = "dotnet sln add ", items = { project_to_add_path } },
	}
	-- Create a new coroutine for the current run
	async_task = create_async_task(command_and_project, buf)

	-- Start the coroutine with the floating window handles
	coroutine.resume(async_task, buf)
end

return M
