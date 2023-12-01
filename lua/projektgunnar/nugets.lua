local M = {}

-- Function to get all outdated nugets for a project
-- @param project string
function M.outdated_nugets(project)
	-- run the outdated nugets command for the selected project
	return vim.fn.systemlist("dotnet list " .. project .. " package --outdated  | awk '/>/{print $2}'")
end

return M
