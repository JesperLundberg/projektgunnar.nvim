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
local function create_async_task(project_path, nuget_list, win, buf)
	return coroutine.create(function()
		local total_nugets = #nuget_list

		-- Loop through all nugets and update them
		for i, nuget in ipairs(nuget_list) do
			-- Construct the dotnet command
			local dotnet_command = "dotnet add " .. project_path .. " package " .. nuget

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

-- Function to update nugets in project
-- @param project_path string
-- @param nuget_list table
function M.UpdateNugetsInProject(project_path, nuget_list)
	-- Open a floating window and get handles
	local win, buf = floating_window.open()

	-- Reset and cleanup from previous run
	reset_and_cleanup()

	-- Create a new coroutine for the current run
	async_task = create_async_task(project_path, nuget_list, win, buf)

	-- Start the coroutine with the floating window handles
	coroutine.resume(async_task, win, buf)
end

return M
