local M = {}

--- Function to get all outdated nugets for a project
--- @param project string the project to get outdated nugets for
--- @param nuget_config_file string the nuget.config file to use
--- @return table
function M.outdated_nugets(project, nuget_config_file)
	-- run the outdated nugets command for the selected project with nuget.config file if one is provided
	if nuget_config_file == nil or nuget_config_file == "" then
		return vim.fn.systemlist("dotnet list " .. project .. " package --outdated | awk '/>/{print $2}'")
	end

	return vim.fn.systemlist(
		"dotnet list "
			.. project
			.. " package --outdated --configfile "
			.. nuget_config_file
			.. " | awk '/>/{print $2}'"
	)
end

--- Function to get all nugets for a project
--- @param project string the project to get all nugets for
--- @return table
function M.all_nugets(project)
	-- run the all nugets command for the selected project
	return vim.fn.systemlist("dotnet list " .. project .. " package | awk '/>/{print $2}'")
end

return M
