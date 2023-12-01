local M = {}

-- Function to get all projects in the solution
function M.get_all_projects_in_solution()
	-- run the dotnet command from the root of the project using solution file got get all available projects
	local output = vim.fn.systemlist("dotnet sln list")

	-- remove the first two lines from the output as they are Projects and ----------
	return vim.list_slice(output, 3, #output)
end

-- Present the list of projects to the user (numbered to make it easier for the user) and return the selected project
function M.ask_user_for_project(projects)
	local inputlist_choices = {}

	-- Give each project a number and add it to the list of choices
	for idx, choice in ipairs(projects) do
		table.insert(inputlist_choices, tostring(idx) .. ". " .. choice)
	end

	-- Add a newline to make the output look nicer
	vim.api.nvim_out_write("\n")

	-- Show the indexed list to the user using vim.fn.inputlist
	local user_input = vim.fn.inputlist(inputlist_choices)

	-- Extract the index from the user's input
	local chosen_index = tonumber(string.match(user_input, "^(%d+)"))

	-- Return the project at the chosen index
	return projects[chosen_index]
end

return M
