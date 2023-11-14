local M = {}

function M.UpdatePackages()
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

	-- ask user to select a project
	local selectedIndexInProjectList = vim.fn.inputlist(projects)

	-- run the update nugets command for the selected package
	local outdatedNugets = vim.fn.system(
		"dotnet list " .. projects[selectedIndexInProjectList] .. " package --outdated | awk '/>/{print $2}'"
	)
end

vim.api.nvim_create_user_command("UpdatePackages", M.UpdatePackages, {})

return M
