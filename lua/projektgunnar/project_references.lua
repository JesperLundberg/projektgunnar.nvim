local utils = require("projektgunnar.utils")

local M = {}

function M.add_project_reference()
	-- get all project in the solution
	local projects = utils.get_all_projects_in_solution()

	-- ask user to select a project
	print("Select a project to add as reference:\n")
	local selectedProjectIndex = utils.get_selected_index_in_project_list(projects)
	local projectToAddTo = projects[selectedProjectIndex]

	print("Select a project to add as reference to " .. projectToAddTo .. ":\n")

	-- Remove the project that is being added to from the list of projects to add as reference
	table.remove(projects, selectedProjectIndex)

	selectedProjectIndex = utils.get_selected_index_in_project_list(projects)
	local projectToAdd = projects[selectedProjectIndex]

	-- add reference to project
	local resultOfNugetAdd = vim.fn.system("dotnet add " .. projectToAddTo .. " reference " .. projectToAdd)

	-- print result of add in result buffer

	-- TODO: Make sure the output is printed to the result buffer

	utils.open_result_buffer(resultOfNugetAdd)
end

return M
