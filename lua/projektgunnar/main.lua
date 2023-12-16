local floating_window = require("projektgunnar.floating_window")

local M = {}

local async_task

-- Function to reset and clean up after each run
local function reset_and_cleanup()
	-- Stop the coroutine if it's running
	if async_task and coroutine.status(async_task) == "running" then
		coroutine.yield()
	end

	-- Reset the async task
	async_task = nil
end

-- Coroutine function to perform asynchronous task
-- @param command_and_item table
-- @param win number
-- @param buf number
local function create_async_task(command_and_items, win, buf)
	return coroutine.create(function()
		-- loop through the command and item table
		for i, command_and_item in ipairs(command_and_items) do
			-- assert command and nugets variables so they are not nil
			assert(command_and_item.command, "command_and_item.command is nil")
			assert(command_and_item.items, "command_and_item.items is nil")

			local total_commands = #command_and_items
			local total_nugets = #command_and_item.items

			-- Print progress
			floating_window.update_progress(win, buf, i, total_commands)

			-- Loop through all nugets and update them
			for j, item_to_add in ipairs(command_and_item.items) do
				-- Construct the dotnet command
				local dotnet_command = command_and_item.command .. item_to_add

				-- Initialize success
				local success = false

				-- Start an external command as a job (non-blocking)
				vim.fn.jobstart(dotnet_command, {
					on_exit = function(_, code)
						-- Check the exit code if needed
						if code == 0 then
							-- Update buffer lines with the current iteration (success)
							success = true
						end

						-- Update buffer with success/failure information
						floating_window.update(win, buf, j, total_nugets, success, dotnet_command)

						-- Resume the coroutine for the next iteration
						coroutine.resume(async_task, win, buf)
					end,
				})

				-- Suspend the coroutine until the job exit callback is executed
				coroutine.yield()
			end

			-- when all work is done, update the floating window with a done message
			if #command_and_items == i then
				floating_window.update_with_done_message(win, buf)
			end
		end
		-- After all iterations are complete, reset and clean up
		M.reset_and_cleanup()
	end)
end

-- Function to add or update nugets in/to project
-- @param command_and_nugets table
function M.AddOrUpdateNugetsInProject(command_and_nugets)
	-- Open a floating window and get handles
	local win, buf = floating_window.open()

	local project_or_solution = #command_and_nugets and " solution" or " project"

	-- Notify the user that the command will add or update nugets
	floating_window.print_message(win, buf, "Adding or updating nugets in" .. project_or_solution)

	-- Reset and cleanup from previous run
	reset_and_cleanup()

	-- Create a new coroutine for the current run
	async_task = create_async_task(command_and_nugets, win, buf)

	-- Start the coroutine with the floating window handles
	coroutine.resume(async_task, win, buf)
end

-- Function to add project to project
-- @param project_path string
-- @param project_to_add_path string
function M.AddProjectToProject(project_path, project_to_add_path)
	-- Open a floating window and get handles
	local win, buf = floating_window.open()

	-- Notify the user that the command will add project to project
	floating_window.print_message(win, buf, "Adding project " .. project_to_add_path .. " to project " .. project_path)

	-- Reset and cleanup from previous run
	reset_and_cleanup()

	local command_and_project = {
		[1] = { command = "dotnet add " .. project_path .. " reference ", items = { project_to_add_path } },
	}
	-- Create a new coroutine for the current run
	async_task = create_async_task(command_and_project, win, buf)

	-- Start the coroutine with the floating window handles
	coroutine.resume(async_task, win, buf)
end

return M
