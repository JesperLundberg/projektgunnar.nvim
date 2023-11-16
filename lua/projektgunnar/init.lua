local nugets = require("projektgunnar.nugets")

local M = {}

vim.api.nvim_create_user_command(
	"UpdatePackagesInProject",
	nugets.update_packages_in_solution,
	{ desc = "Update nugets in project" }
)

return M
