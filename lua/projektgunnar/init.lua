local function tab_completion(_, _, _)
	-- Tab completion for the commands below
	local commands = {
		"AddProjectToSolution",
		"AddNugetToProject",
		"RemoveNugetFromProject",
		"UpdateNugetsInProject",
		"UpdateNugetsInSolution",
		"AddProjectToProject",
		"RemoveProjectFromProject",
	}

	return commands
end

vim.api.nvim_create_user_command("ProjektGunnar", function(opts)
	-- Create a table of commands
	local commands = {
		["AddProjectToSolution"] = function()
			require("projektgunnar.main").add_project_to_solution()
		end,
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
	}

	-- If the command exists then run the corresponding function
	commands[opts.args]()
end, { nargs = "*", complete = tab_completion, desc = "ProjektGunnar plugin" })
