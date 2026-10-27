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
	["ForgetCachedSolutionFile"] = function()
		require("projektgunnar.solution").forget_cached_solution_file()
	end,
}

local function tab_completion(arg_lead, _, _)
	-- Tab completion for ProjektGunnar: sorted and filtered by what is typed
	local keys = vim.tbl_keys(commands)
	table.sort(keys)

	local lead = (arg_lead or ""):lower()
	return vim.tbl_filter(function(k)
		return vim.startswith(k:lower(), lead)
	end, keys)
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
end, { nargs = "?", complete = tab_completion, desc = "ProjektGunnar plugin" })

function M.setup(opts)
	-- Setup the plugin
	require("projektgunnar.config").setup(opts)
end

return M
