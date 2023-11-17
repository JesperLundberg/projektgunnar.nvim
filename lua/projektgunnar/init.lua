local nugets = require("projektgunnar.nugets")
local project_references = require("projektgunnar.project_references")

local M = {}

vim.api.nvim_create_user_command(
	"AddProjectReference",
	project_references.add_project_reference,
	{ desc = "Add project reference" }
)

vim.api.nvim_create_user_command(
	"AddPackagesToProject",
	nugets.add_packages_to_project,
	{ desc = "Add nuget to project" }
)

vim.api.nvim_create_user_command(
	"UpdatePackagesInSolution",
	nugets.update_packages_in_solution,
	{ desc = "Update nugets in project" }
)

return M
