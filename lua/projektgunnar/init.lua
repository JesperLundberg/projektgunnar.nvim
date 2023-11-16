local M = {}

-- Define a function to open a new buffer and print results
function OpenResultBuffer(results)
	-- Create a new buffer
	local result_buffer = vim.api.nvim_create_buf(false, true)

	-- Open the buffer in a new window
	vim.api.nvim_command("split")

	-- Set the buffer as the current buffer
	vim.api.nvim_set_current_buf(result_buffer)

	-- Convert the string into a table of lines
	local lines = vim.split(results, "\n")

	-- Set the buffer's content
	vim.api.nvim_buf_set_lines(result_buffer, 0, -1, false, lines)

	-- Set the buffer to be unmodifiable
	vim.api.nvim_buf_set_option(result_buffer, "modifiable", false)

	-- Set the buffer name (optional)
	vim.api.nvim_buf_set_name(result_buffer, "ResultBuffer")

	-- Set the buffer to read-only (optional)
	vim.api.nvim_buf_set_option(result_buffer, "readonly", true)
end

function GetAllProjectsInSolution()
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

function M.UpdatePackagesInProject()
	local projects = GetAllProjectsInSolution()

	-- ask user to select a project
	local selectedIndexInProjectList = vim.fn.inputlist(projects)

	-- run the update nugets command for the selected package
	local outdatedNugets = vim.fn.system(
		"dotnet list " .. projects[selectedIndexInProjectList] .. " package --outdated  | awk '/>/{print $2}'"
	)

	-- print the output of the command, if it's empty, print that it is empty
	if outdatedNugets == "" then
		print("\nNo outdated nugets found")
		return
	end
	print("\n" .. outdatedNugets)

	-- run the update command for each outdated nugets
	local resultOfNugetUpdate = {}

	-- get the total number of outdated nugets from outdatedNugets
	local totalNumberOfOutdatedNugets = 0
	for _ in string.gmatch(outdatedNugets, "%S+") do
		totalNumberOfOutdatedNugets = totalNumberOfOutdatedNugets + 1
	end

	-- update each nuget and print the progress
	local currentNumberOfOutdatedNugets = 0
	for outdatedNuget in string.gmatch(outdatedNugets, "%S+") do
		currentNumberOfOutdatedNugets = currentNumberOfOutdatedNugets + 1
		print("Updating nuget " .. currentNumberOfOutdatedNugets .. " of " .. totalNumberOfOutdatedNugets)
		resultOfNugetUpdate =
			vim.fn.system("dotnet add " .. projects[selectedIndexInProjectList] .. " package " .. outdatedNuget)
	end

	-- print result of update in result buffer
	OpenResultBuffer(resultOfNugetUpdate)
end

vim.api.nvim_create_user_command("UpdatePackagesInProject", M.UpdatePackagesInProject, {})

return M
