local M = {}

-- function to require a module and return nil if it fails
-- @param module string
function M.prequire(module)
	local ok, err = pcall(require, module)
	if not ok then
		return nil, err
	end
	return err
end

-- get all the references that provided project has
-- @param project string
-- @return table
function M.get_project_references(project)
	-- get all references
	local output = vim.fn.systemlist("dotnet list " .. project .. " reference")

	-- remove the first two characters of each line as that is dotdot and change all backslashes to forward slashes
	for i, v in ipairs(output) do
		output[i] = string.sub(v, 3).gsub(v, "\\", "/")
	end

	-- remove the first two lines from the output as they are Projects and ----------
	return vim.list_slice(output, 3, #output)
end

-- Function to get all projects in the solution
-- @return table
function M.get_all_projects_in_solution()
	-- run the dotnet command from the root of the project using solution file got get all available projects
	local output = vim.fn.systemlist("dotnet sln list")

	-- remove the first two lines from the output as they are Projects and ----------
	return vim.list_slice(output, 3, #output)
end

-- returns all projects that are not already in the solution file
-- @return table
function M.get_all_projects_in_solution_folder_not_in_solution()
	-- find all csproj files in the solution folders
	local output = vim.fn.systemlist("find . -name '*.csproj'")

	-- remove the first two characters of each line as that is a dot and a slash
	for i, v in ipairs(output) do
		output[i] = string.sub(v, 3)
	end

	return output
end

-- find out if table has the provided value
-- @param tab table
-- @param val string
-- @return bool
function M.has_value(tab, val)
	for _, value in ipairs(tab) do
		if value == val then
			return true
		end
	end

	return false
end

-- function to concatenate two tables (destructive on t1)
-- @param t1 table
-- @param t2 table
-- @return table
function M.table_concat(t1, t2)
	for i = 1, #t2 do
		t1[#t1 + 1] = t2[i]
	end

	return t1
end

return M
