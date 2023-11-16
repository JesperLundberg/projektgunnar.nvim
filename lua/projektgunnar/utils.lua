local M = {}

function M.open_result_buffer(results)
	-- Create a new buffer
	local result_buffer = vim.api.nvim_create_buf(false, true)

	-- Open the buffer in a new window
	vim.api.nvim_command("split")

	-- Set the buffer as the current buffer
	vim.api.nvim_set_current_buf(result_buffer)

	-- Convert the string into a table of lines
	local lines = vim.split(results, "\n")

	-- Remove all lines except for the ones that contain the word "error"
	local lines_with_errors = {}
	for _, line in ipairs(lines) do
		if string.find(line, "error") then
			table.insert(lines_with_errors, line)
		end
	end

	-- Set the buffer's content
	if #lines_with_errors > 0 then
		vim.api.nvim_buf_set_lines(result_buffer, 0, -1, false, lines_with_errors)
	else
		-- get the lines containing the word PackageReference for package updated
		local lines_with_package_updates = {}
		for _, line in ipairs(lines) do
			if string.find(line, "PackageReference for package") then
				table.insert(lines_with_package_updates, line)
			end
		end
		vim.api.nvim_buf_set_lines(result_buffer, 0, -1, false, lines)
	end

	-- Set the buffer to be unmodifiable
	vim.api.nvim_buf_set_option(result_buffer, "modifiable", false)

	-- Set the buffer name (optional)
	vim.api.nvim_buf_set_name(result_buffer, "ResultBuffer")

	-- Set the buffer to read-only (optional)
	vim.api.nvim_buf_set_option(result_buffer, "readonly", true)
end

return M
