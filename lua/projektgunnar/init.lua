-- Available commands for ProjektGunnar
local commands = {
	["AddNugetToProject"] = function()
		require("projektgunnar.main").add_nuget_to_project()
	end,
	["RemoveNugetFromProject"] = function()
		require("projektgunnar.main").remove_nuget_from_project()
	end,
	["UpdateNugetsInProject"] = function()
		require("projektgunnar.main").update_nugets_in_project()
	end,
	["UpdateNugetsInSolution"] = function()
		require("projektgunnar.main").update_nugets_in_solution()
	end,
	["AddProjectToProject"] = function()
		require("projektgunnar.main").add_project_reference()
	end,
	["RemoveProjectFromProject"] = function()
		require("projektgunnar.main").remove_project_reference()
	end,
	["AddProjectToSolution"] = function()
		require("projektgunnar.main").add_project_to_solution()
	end,
}

local function tab_completion(_, _, _)
	-- Tab completion for ProjektGunnar
	local tab_commands = {}

	-- Loop through the commands and add the key value to the tab completion
	for k, _ in pairs(commands) do
		table.insert(tab_commands, k)
	end

	return tab_commands
end

vim.api.nvim_create_user_command("ProjektGunnar", function(opts)
	-- If the command exists then run the corresponding function
	commands[opts.args]()
end, { nargs = "*", complete = tab_completion, desc = "ProjektGunnar plugin" })
