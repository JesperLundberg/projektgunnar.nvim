local M = {}

-- Function to get all projects in the solution
-- @return table
function M.get_all_projects_in_solution()
	-- run the dotnet command from the root of the project using solution file got get all available projects
	local output = vim.fn.systemlist("dotnet sln list")

	-- remove the first two lines from the output as they are Projects and ----------
	return vim.list_slice(output, 3, #output)
end

function M.get_all_projects_in_solution_folder_not_in_solution()
	-- find all csproj files in the solution folders
	local output = vim.fn.systemlist("find . -name '*.csproj'")

	-- remove the first two characters of each line as that is a dot and a slash
	for i, v in ipairs(output) do
		output[i] = string.sub(v, 3)
	end

	return output
end

function M.has_value(tab, val)
	for _, value in ipairs(tab) do
		if value == val then
			return true
		end
	end

	return false
end

-- Function to concatenate two tables
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
