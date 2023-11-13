local M = {}

function M.AddPackage()
	-- run the dotnet command from the root of the project using solution file got get all available projects
	local output = vim.fn.systemlist("dotnet sln list")
	local projects = {}
	for _, project in ipairs(output) do
		table.insert(projects, project)
	end

	-- ask user to select a project
	local project = vim.fn.inputlist(projects)
end

return M
