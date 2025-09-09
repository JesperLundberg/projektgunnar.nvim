-- Fault-tolerant NuGet helpers using vim.system + async.wrap_cb pattern.
-- Usage (inside async.run coroutine):
--   local pkgs, err = require("projektgunnar.nugets").all_nugets(project)
--   local outdated, err = require("projektgunnar.nugets").outdated_nugets(project, cfg)

local async = require("projektgunnar.async")

local M = {}

-- Normalize opts and ensure we always get a table we can mutate.
--- @param opts { cwd?: string, text?: boolean }|nil
--- @return { cwd?: string, text?: boolean }
local function normalize_opts(opts)
	if type(opts) ~= "table" then
		opts = {}
	end
	opts.text = true
	--- @type { cwd?: string, text?: boolean }
	return opts
end

-- Safe tostring
local function to_s(x)
	local ok, s = pcall(function()
		return tostring(x)
	end)
	return ok and s or "<non-printable>"
end

-- Parse package ids from `dotnet list` output.
--- @param stdout string|nil
--- @return string[]  -- never nil
local function parse_packages(stdout)
	local pkgs = {}
	if type(stdout) ~= "string" or stdout == "" then
		return pkgs
	end
	for line in stdout:gmatch("[^\r\n]+") do
		-- dotnet marks package rows with '>' (works across SDK versions/locales)
		if line:find(">", 1, true) then
			local name = line:match("^%s*>%s*(%S+)")
			if name and name ~= ">" then
				table.insert(pkgs, name)
			end
		end
	end
	return pkgs
end

-- Low-level runner: ALWAYS calls cb(result|nil, err|nil). Never throws.
--- @param args string[]
--- @param opts { cwd?: string, text?: boolean }|nil
--- @param cb fun(pkgs: string[]|nil, err?: string)
local function run_dotnet_list(args, opts, cb)
	local ok, err = pcall(function()
		opts = normalize_opts(opts)

		vim.system({ "dotnet", unpack(args) }, opts, function(obj)
			local _ok, _err = pcall(function()
				local code = (obj and obj.code) or -1
				local stdout = (obj and obj.stdout) or ""
				local stderr = (obj and obj.stderr) or ""

				if code ~= 0 then
					cb(nil, ("dotnet exited with %d: %s"):format(code, to_s(stderr)))
					return
				end

				local pkgs = parse_packages(stdout)
				cb(pkgs, nil)
			end)

			if not _ok then
				cb(nil, "nugets: callback failure: " .. to_s(_err))
			end
		end)
	end)

	if not ok then
		cb(nil, "nugets: spawn failure: " .. to_s(err))
	end
end

-- Your async.wrap_cb appends resume as the LAST arg; we MUST pass opts explicitly.
local run_dotnet_list_direct = async.wrap_cb(run_dotnet_list)

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

--- List all NuGet packages in a project.
--- @param project string
--- @param opts { cwd?: string, text?: boolean }|nil
--- @return string[]|nil, string|nil
function M.all_nugets(project, opts)
	opts = normalize_opts(opts) -- ensure (args, opts, resume)
	return run_dotnet_list_direct({ "list", project, "package" }, opts)
end

--- List all outdated NuGet packages in a project.
--- @param project string
--- @param nuget_config_file string|nil
--- @param opts { cwd?: string, text?: boolean }|nil
--- @return string[]|nil, string|nil
function M.outdated_nugets(project, nuget_config_file, opts)
	local args = { "list", project, "package", "--outdated" }
	if nuget_config_file and nuget_config_file ~= "" then
		table.insert(args, "--configfile")
		table.insert(args, nuget_config_file)
	end
	opts = normalize_opts(opts) -- ensure (args, opts, resume)
	return run_dotnet_list_direct(args, opts)
end

return M
