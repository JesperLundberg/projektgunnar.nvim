local main = require("projektgunnar.main")

vim.api.nvim_create_user_command(
	"AddProjectToSolution",
	main.AddProjectToSolution,
	{ desc = "Add project to solution" }
)
vim.api.nvim_create_user_command("AddNugetToProject", main.AddNugetToProject, { desc = "Add Nuget to Project" })
vim.api.nvim_create_user_command(
	"RemoveNugetFromProject",
	main.RemoveNugetFromProject,
	{ desc = "Remove Nuget from Project" }
)
vim.api.nvim_create_user_command(
	"UpdateNugetsInProject",
	main.UpdateNugetsInProject,
	{ desc = "Update Nugets in Project" }
)
vim.api.nvim_create_user_command(
	"UpdateNugetsInSolution",
	main.UpdateNugetsInSolution,
	{ desc = "Update Nugets in Solution" }
)
vim.api.nvim_create_user_command(
	"AddProjectToProject",
	main.AddProjectToProject,
	{ desc = "Add one project as a reference to another" }
)
