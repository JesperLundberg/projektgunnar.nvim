local utils = require("projektgunnar.utils")

local M = {}
M.result = {}

local async_task

-- Coroutine function to perform asynchronous task
async_task = coroutine.create(function(total_iterations, dotnet_args)
	for i = 1, total_iterations do
		-- Start an external command as a job (non-blocking)
		vim.fn.jobstart("dotnet", {
			args = dotnet_args, -- Pass additional arguments here
			on_stderr = function(err, _)
				if err ~= nil then
					utils.update_view(err)
				end
			end,
			on_exit = function(result, exit_code)
				local tableResult = {}
				table.insert(tableResult, result)
				-- Save the result in a tables
				utils.concatenate_tables(M.result, tableResult)

				-- Check the exit code if needed
				if exit_code == 0 then
					-- Update buffer lines with the current iteration
					utils.update_view(i .. " out of " .. total_iterations)

					-- Resume the coroutine for the next iteration
					coroutine.resume(async_task)
				end
			end,
		})

		-- Suspend the coroutine until the job exit callback is executed
		coroutine.yield()
	end
end)

-- Function to start the coroutine
function M.start_coroutine(total_iterations, dotnet_args)
	-- Set up the buffer
	vim.api.nvim_create_buf(false, true)

	-- Set the buffer as the current buffer
	vim.api.nvim_set_current_buf(0)

	-- Start the coroutine
	coroutine.resume(async_task, total_iterations, dotnet_args)
end

return M
