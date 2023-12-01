local M = {}

function M.get_all_projects_in_solution()
	-- run the dotnet command from the root of the project using solution file got get all available projects
	local output = vim.fn.systemlist("dotnet sln list")

	-- remove the first two lines from the output
	local projects = vim.list_slice(output, 3, #output)

	return projects
end

return M
