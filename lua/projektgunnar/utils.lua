local M = {}

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
	if #lines_with_errors > 0 then
		vim.api.nvim_buf_set_lines(result_buffer, 0, -1, false, lines_with_errors)
	else
		-- get the lines containing the word PackageReference for package updated
		local lines_with_package_reference = M.get_lines_from_table(lines, output_regex_table.success)
		vim.api.nvim_buf_set_lines(result_buffer, 0, -1, false, lines_with_package_reference)
	end

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

return M
