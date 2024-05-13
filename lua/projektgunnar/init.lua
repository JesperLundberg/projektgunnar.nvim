vim.api.nvim_create_user_command("AddProjectToSolution", function()
	require("projektgunnar.main").add_project_to_solution()
end, { desc = "Add project to solution" })

vim.api.nvim_create_user_command("AddNugetToProject", function()
	require("projektgunnar.main").add_nuget_to_project()
end, { desc = "Add Nuget to Project" })

vim.api.nvim_create_user_command("RemoveNugetFromProject", function()
	require("projektgunnar.main").remove_nuget_from_project()
end, { desc = "Remove Nuget from Project" })

vim.api.nvim_create_user_command("UpdateNugetsInProject", function()
	require("projektgunnar.main").update_nugets_in_project()
end, { desc = "Update Nugets in Project" })

vim.api.nvim_create_user_command("UpdateNugetsInSolution", function()
	require("projektgunnar.main").update_nugets_in_solution()
end, { desc = "Update Nugets in Solution" })

vim.api.nvim_create_user_command("AddProjectToProject", function()
	require("projektgunnar.main").add_project_reference()
end, { desc = "Add one project as a reference to another" })

vim.api.nvim_create_user_command("RemoveProjectFromProject", function()
	require("projektgunnar.main").remove_project_reference()
end, { desc = "Remove one project reference from a project" })
