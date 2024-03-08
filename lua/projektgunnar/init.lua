local main = require("projektgunnar.main")

vim.api.nvim_create_user_command(
	"AddProjectToSolution",
	main.add_project_to_solution,
	{ desc = "Add project to solution" }
)
vim.api.nvim_create_user_command("AddNugetToProject", main.add_nuget_to_project, { desc = "Add Nuget to Project" })
vim.api.nvim_create_user_command(
	"RemoveNugetFromProject",
	main.remove_nuget_from_project,
	{ desc = "Remove Nuget from Project" }
)
vim.api.nvim_create_user_command(
	"UpdateNugetsInProject",
	main.update_nugets_in_project,
	{ desc = "Update Nugets in Project" }
)
vim.api.nvim_create_user_command(
	"UpdateNugetsInSolution",
	main.update_nugets_in_solution,
	{ desc = "Update Nugets in Solution" }
)
vim.api.nvim_create_user_command(
	"AddProjectToProject",
	main.add_project_reference,
	{ desc = "Add one project as a reference to another" }
)
vim.api.nvim_create_user_command(
	"RemoveProjectFromProject",
	main.remove_project_reference,
	{ desc = "Remove one project reference from a project" }
)
