local M = {}

function M.UpdatePackagesInProject()
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

	-- print the output of the command, if it's empty, print that it is empty
	if outdatedNugets == "" then
		print("No outdated nugets found")
		return
	end
	print(outdatedNugets)

	-- run the update command for each outdated nugets
	local updatedNugets = {}
	for outdatedNuget in string.gmatch(outdatedNugets, "%S+") do
		updatedNugets =
			vim.fn.system("dotnet add " .. projects[selectedIndexInProjectList] .. " package " .. outdatedNuget)
	end

	-- print all updated nugets
	print(updatedNugets)
end

vim.api.nvim_create_user_command("UpdatePackagesInProject", M.UpdatePackagesInProject, {})

return M
