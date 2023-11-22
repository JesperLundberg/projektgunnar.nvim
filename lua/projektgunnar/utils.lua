local M = {}

local api = vim.api
local buf, win

-- Floating result buffer
function M.open_window()
	-- create a new scratch buffer
	buf = api.nvim_create_buf(false, true)
	-- create a new window for the border
	local border_buf = api.nvim_create_buf(false, true)

	api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	api.nvim_buf_set_option(buf, "filetype", "projektgunnar")

	local width = api.nvim_get_option("columns")
	local height = api.nvim_get_option("lines")

	local win_height = math.ceil(height * 0.8 - 4)
	local win_width = math.ceil(width * 0.8)
	local row = math.ceil((height - win_height) / 2 - 1)
	local col = math.ceil((width - win_width) / 2)

	local border_opts = {
		style = "minimal",
		relative = "editor",
		width = win_width + 2,
		height = win_height + 2,
		row = row - 1,
		col = col - 1,
	}

	local opts = {
		style = "minimal",
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
	}

	-- Set the border symbols
	local border_lines = { "╔" .. string.rep("═", win_width) .. "╗" }
	local middle_line = "║" .. string.rep(" ", win_width) .. "║"
	for _ = 1, win_height do
		table.insert(border_lines, middle_line)
	end
	table.insert(border_lines, "╚" .. string.rep("═", win_width) .. "╝")
	api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

	api.nvim_open_win(border_buf, true, border_opts)
	win = api.nvim_open_win(buf, true, opts)
	-- if the buffer is closed, close the border buffer as well
	api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "' .. border_buf)

	api.nvim_win_set_option(win, "cursorline", true) -- it highlight line with the cursor on it

	-- we can add title already here, because first line will never change
	api.nvim_buf_set_lines(buf, 0, -1, false, { M.center("ProjektGunnar"), "", "" })
	api.nvim_buf_add_highlight(buf, -1, "PGHeader", 0, 0, -1)
end

-- Method to set the content of the window
function M.update_view(output)
	api.nvim_buf_set_option(buf, "modifiable", true)

	-- if the output is a string, convert it to a table
	if type(output) == "string" then
		output = vim.split(output, "\n")
	end

	if #output == 0 then
		table.insert(output, "")
	end -- add  an empty line to preserve layout if there is no results
	for k, _ in pairs(output) do
		output[k] = "  " .. output[k]
	end

	api.nvim_buf_set_lines(buf, 3, -1, false, output)

	print("before highlight")
	api.nvim_buf_add_highlight(buf, -1, "PGHeader", 1, 0, -1)
	api.nvim_buf_set_option(buf, "modifiable", false)
end

-- Method to center a string in a window
function M.center(str)
	local width = api.nvim_win_get_width(0)
	local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
	return string.rep(" ", shift) .. str
end

-- Method to close the window
function M.close_window()
	api.nvim_win_close(win, true)
end

-- Present the list of projects to the user and return the selected project
function M.get_selected_index_in_project_list(projects)
	local inputlist_choices = {}
	for idx, choice in ipairs(projects) do
		table.insert(inputlist_choices, tostring(idx) .. ". " .. choice)
	end

	-- Show the indexed list to the user using vim.fn.inputlist
	local user_input = vim.fn.inputlist(inputlist_choices)

	-- Extract the index from the user's input
	local selected_index = tonumber(string.match(user_input, "^(%d+)"))

	return selected_index
end

-- Get all lines from the table that match the specified pattern
function M.get_lines_from_table(input_table, regex)
	local matches = {}

	-- Iterate through each line in the table
	for _, line in ipairs(input_table) do
		-- Check if the line matches the specified pattern
		if line:match(regex) then
			-- Add the line to the matches table
			table.insert(matches, line)
		end
	end

	return matches
end

-- Open a new buffer with the specified results
function M.open_result_buffer(results, output_regex_table)
	-- Create a new buffer
	local result_buffer = vim.api.nvim_create_buf(false, true)

	-- Open the buffer in a new window
	vim.api.nvim_command("split")

	-- Set the buffer as the current buffer
	vim.api.nvim_set_current_buf(result_buffer)

	-- Convert the string into a table of lines
	local lines = vim.split(results, "\n")

	-- Get the lines containing errors
	local lines_with_errors = M.get_lines_from_table(lines, output_regex_table.error)

	-- Set the buffer's content
	-- Add the lines with errors to the lines with successes
	local lines_with_package_reference =
		M.concatenate_tables(M.get_lines_from_table(lines, output_regex_table.success), lines_with_errors)

	-- Set the buffer's content
	vim.api.nvim_buf_set_lines(result_buffer, 0, -1, false, lines_with_package_reference)

	-- Set the buffer to be unmodifiable
	vim.api.nvim_buf_set_option(result_buffer, "modifiable", false)

	-- Set the buffer name (optional)
	vim.api.nvim_buf_set_name(result_buffer, "ResultBuffer")

	-- Set the buffer to read-only (optional)
	vim.api.nvim_buf_set_option(result_buffer, "readonly", true)
end

-- get all projects in the solution
function M.get_all_projects_in_solution()
	-- run the dotnet command from the root of the project using solution file got get all available projects
	local output = vim.fn.systemlist("dotnet sln list")
	local projects = {}

	-- do not add the first two lines to the list of projects
	for _, project in ipairs(output) do
		if project == "Project(s)" or project == "----------" then
			goto continue
		end
		table.insert(projects, project)
		::continue::
	end

	return projects
end

-- function that concatenates tables, make sure that the tables are not nil
function M.concatenate_tables(table1, table2)
	local concatenated_table = {}
	if table1 ~= nil then
		for _, value in ipairs(table1) do
			table.insert(concatenated_table, value)
		end
	end
	if table2 ~= nil then
		for _, value in ipairs(table2) do
			table.insert(concatenated_table, value)
		end
	end
	return concatenated_table
end

return M
