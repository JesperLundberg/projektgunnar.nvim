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
local function create_async_task(dotnet_command_arguments, table_of_items_to_add, win, buf)
	return coroutine.create(function()
		local total_nugets = #table_of_items_to_add

		-- Loop through all nugets and update them
		for i, item_to_add in ipairs(table_of_items_to_add) do
			-- Construct the dotnet command
			local dotnet_command = "dotnet " .. dotnet_command_arguments .. item_to_add

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
					floating_window.update(win, buf, i, total_nugets, success, dotnet_command)

					-- Resume the coroutine for the next iteration
					coroutine.resume(async_task, win, buf)
				end,
			})

			-- Suspend the coroutine until the job exit callback is executed
			coroutine.yield()
		end

		-- After all iterations are complete, reset and clean up
		M.reset_and_cleanup()
	end)
end

-- Function to add or update nugets in/to project
-- @param project_path string
-- @param nuget_list table
function M.AddOrUpdateNugetsInProject(project_path, nuget_table)
	-- Open a floating window and get handles
	local win, buf = floating_window.open()

	-- Reset and cleanup from previous run
	reset_and_cleanup()

	-- Create a new coroutine for the current run
	async_task = create_async_task("add " .. project_path .. " package ", nuget_table, win, buf)

	-- Start the coroutine with the floating window handles
	coroutine.resume(async_task, win, buf)
end

return M
