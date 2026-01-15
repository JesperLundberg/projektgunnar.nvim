local M = {}

--- Find file(s)
---@param dir string where to search from (usually cwd)
---@param pattern string which file to find
---@param limit number|nil) how many files to return
---@return table
local function find_files_under(dir, pattern, limit)
	limit = limit or math.huge

	local expr = dir .. "/**/" .. pattern
	local matches = vim.fn.glob(expr, false, true) -- return list

	if #matches <= limit then
		return matches
	end

	-- Return only the first 'limit' matches.
	return vim.list_slice(matches, 1, limit)
end

--- function to require a module and return nil if it fails
--- @param module string the module to require (safely)
function M.prequire(module)
	local ok, mod = pcall(require, module)
	if not ok then
		return nil, mod
	end
	return mod
end

--- get all solution files below cwd
--- @return table
function M.get_all_solution_files()
	local cwd = vim.fn.getcwd()

	-- get all solution files
	local files = find_files_under(cwd, "*.sln")

	return files
end

--- get the nuget.config file for the solution
--- @return string
function M.get_nuget_config_file()
	-- get the current working directory
	local cwd = vim.fn.getcwd()

	local file = find_files_under(cwd, "nuget.config", 1)

	-- return the config file path
	return file[1] -- return the first element of the table
end

--- get all the references that provided project has
--- @param project string the project to get references for
--- @return table
function M.get_project_references(project)
	-- get all references
	local output = vim.fn.systemlist({ "dotnet", "list", project, "reference" })

	-- remove the first two characters of each line as that is dotdot and change all backslashes to forward slashes
	for i, v in ipairs(output) do
		output[i] = string.sub(v, 3):gsub("\\", "/")
	end

	-- remove the first two lines from the output as they are Projects and ----------
	return vim.list_slice(output, 3, #output)
end

--- Function to get all projects in a specific solution
--- @param sln_path string
--- @return table
function M.get_all_projects_in_solution(sln_path)
	local output = vim.fn.systemlist({ "dotnet", "sln", sln_path, "list" })

	local rows = vim.list_slice(output, 3, #output)

	local sln_dir = vim.fs.dirname(sln_path)

	local result = {}
	for _, p in ipairs(rows) do
		local rel = vim.trim(p):gsub("\r", "")
		if rel ~= "" then
			local abs = vim.fs.normalize(vim.fs.joinpath(sln_dir, rel))
			table.insert(result, abs)
		end
	end

	return result
end

--- returns all projects that are not already in the solution file
--- @return table
function M.get_all_project_files()
	-- find all csproj files in the solution folders
	local output = vim.fn.systemlist({ "find", ".", "-name", "*.csproj" })

	-- remove the first two characters of each line as that is a dot and a slash
	for i, v in ipairs(output) do
		output[i] = string.sub(v, 3)
	end

	return output
end

--- find out if table has the provided value
--- @param tab table|nil the table to search
--- @param val string|number|nil the value to search for
--- @return boolean
function M.has_value(tab, val)
	if tab == nil then
		return false
	end

	for _, value in ipairs(tab) do
		if value == val then
			return true
		end
	end

	return false
end

--- function to concatenate two tables (destructive on t1)
--- @param t1 table the table to concatenate to
--- @param t2 table the table to add to t1
--- @return table
function M.table_concat(t1, t2)
	for i = 1, #t2 do
		t1[#t1 + 1] = t2[i]
	end

	return t1
end

return M
