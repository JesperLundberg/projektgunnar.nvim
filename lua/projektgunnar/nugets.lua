local utils = require("projektgunnar.utils")

local M = {}

function M.add_packages_to_project()
	-- ask user to input the name of the package
	local packageName = vim.fn.input("Package name: ")
	print("\n")

	local projects = utils.get_all_projects_in_solution()

	-- ask user to select a project
	local selectedIndexInProjectList = utils.get_selected_index_in_project_list(projects)

	-- run the add nuget command for the selected package
	local resultOfNugetAdd =
		vim.fn.system("dotnet add " .. projects[selectedIndexInProjectList] .. " package " .. packageName)

	-- print result of add in result buffer
	utils.open_window()
	utils.update_view(resultOfNugetAdd)
end

function M.update_packages_in_project()
	local projects = utils.get_all_projects_in_solution()

	-- ask user to select a project
	local selectedIndexInProjectList = utils.get_selected_index_in_project_list(projects)

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

	utils.open_window()
	utils.update_view(resultOfNugetUpdate)
end

function M.update_packages_in_solution()
	local projects = utils.get_all_projects_in_solution()

	-- loop over projects and run the update nugets command for each project
	-- and save the output in a table along with the project
	local outdatedNugets = {}
	for _, project in ipairs(projects) do
		local outdatedNugetsForProject =
			vim.fn.system("dotnet list " .. project .. " package --outdated  | awk '/>/{print $2}'")
		if outdatedNugetsForProject ~= "" then
			table.insert(outdatedNugets, { project = project, outdated = outdatedNugetsForProject })
		end
	end

	-- print the output of the command, if it's empty, print that it is empty
	if outdatedNugets == "" then
		print("\nNo outdated nugets found")
		return
	end

	-- print each project and all nugets under that project, loop through the table
	for _, outdatedNuget in ipairs(outdatedNugets) do
		print("---\n")
		print(outdatedNuget.project)
		print("---\n")
		print(outdatedNuget.outdated)
	end

	-- get the total number of outdated nugets from outdatedNugets
	local totalNumberOfOutdatedNugets = 0
	-- loop through the list outdatedNugets and count the number of outdated nugets
	for _, outdatedNuget in ipairs(outdatedNugets) do
		for _ in string.gmatch(outdatedNuget.outdated, "%S+") do
			totalNumberOfOutdatedNugets = totalNumberOfOutdatedNugets + 1
		end
	end

	print(totalNumberOfOutdatedNugets)

	-- update each nuget and print the progress
	local currentNumberOfOutdatedNugets = 0
	local resultOfNugetUpdate = ""

	for _, outdatedNuget in ipairs(outdatedNugets) do
		for nugetToUpdate in string.gmatch(outdatedNuget.outdated, "%S+") do
			currentNumberOfOutdatedNugets = currentNumberOfOutdatedNugets + 1
			print("Updating nuget " .. currentNumberOfOutdatedNugets .. " of " .. totalNumberOfOutdatedNugets)
			-- run the update command for each outdated nugets and save the output in a string
			resultOfNugetUpdate = resultOfNugetUpdate
				.. vim.fn.system("dotnet add " .. outdatedNuget.project .. " package " .. nugetToUpdate)
		end
	end

	-- print result of update in result buffer
	utils.open_window()
	utils.update_view(resultOfNugetUpdate)
end

return M
