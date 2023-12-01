local M = {}

function M.outdated_nugets(project)
	-- run the outdated nugets command for the selected project
	local outdated_nugets = vim.fn.systemlist("dotnet list " .. project .. " package --outdated  | awk '/>/{print $2}'")

	return outdated_nugets
end

return M
