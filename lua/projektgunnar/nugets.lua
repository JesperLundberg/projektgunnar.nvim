local M = {}

--- function to get the nuget packages from a supplied input
--- @param input table table that contains one line each from output
--- @return table
local function extract_nuget_package_names(input)
	local nugetPackages = {}

	-- Iterate through each line
	for _, line in ipairs(input) do
		-- Extract package name (everything after '> ' until next whitespace)
		-- discard the first two matched groups as we want the nuget name
		local _, _, packageName = line:match("^([%s]*)>([%s]*)(%S+)")

		if packageName then
			-- Add package name to our result table
			table.insert(nugetPackages, packageName)
		end
	end

	return nugetPackages
end

--- Function to get all outdated nugets for a project
--- @param project string the project to get outdated nugets for
--- @return table
function M.outdated_nugets(project)
	-- run the outdated nugets command for the selected project
	return vim.fn.systemlist("dotnet list " .. project .. " package --outdated  | awk '/>/{print $2}'")
end

--- Function to get all nugets for the solution
--- @return table
function M.all_outdated_nugets_in_solution()
	-- run the all nugets command for the solution
	local output = vim.fn.systemlist("dotnet list package --outdated")

	return extract_nuget_package_names(output)
end

--- Function to get all nugets for a project
--- @param project string the project to get all nugets for
--- @return table
function M.all_nugets(project)
	-- run the all nugets command for the selected project
	return vim.fn.systemlist("dotnet list " .. project .. " package | awk '/>/{print $2}'")
end

return M
