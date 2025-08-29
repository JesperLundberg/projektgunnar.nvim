local M = {}

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
	-- No args: show picker and run chosen command via callback
	if opts.args == "" then
		local comms = vim.tbl_keys(commands)
		table.sort(comms)

		require("projektgunnar.picker").ask_user_for_choice("Choose command", comms, function(choice)
			if not choice then
				vim.notify("No command chosen", vim.log.levels.ERROR)
				return
			end
			local fn = commands[choice]
			if not fn then
				vim.notify("Unknown command: " .. tostring(choice), vim.log.levels.ERROR)
				return
			end
			fn()
		end)
	else
		-- With arg: run directly if it exists
		local fn = commands[opts.args]
		if not fn then
			vim.notify("Unknown command: " .. tostring(opts.args), vim.log.levels.ERROR)
			return
		end
		fn()
	end
end, { nargs = "*", complete = tab_completion, desc = "ProjektGunnar plugin" })

function M.setup(opts)
	-- Setup the plugin
	require("projektgunnar.config").setup(opts)
end

return M
