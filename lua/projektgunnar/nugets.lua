local M = {}

-- Function to get all outdated nugets for a project
-- @param project string
-- @return table
function M.outdated_nugets(project)
	-- run the outdated nugets command for the selected project
	return vim.fn.systemlist("dotnet list " .. project .. " package --outdated  | awk '/>/{print $2}'")
end

-- Function to get all nugets for a project
-- @param project string
-- @return table
function M.all_nugets(project)
	-- run the all nugets command for the selected project
	return vim.fn.systemlist("dotnet list " .. project .. " package | awk '/>/{print $2}'")
end

return M
