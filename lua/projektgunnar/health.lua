local M = {}

M.check = function()
	vim.health.start("CLI tools")

	-- Check if `dotnet` is installed
	if vim.fn.executable("dotnet") == 0 then
		vim.health.error("dotnet")
	else
		-- Run `dotnet --version` to get the version of dotnet
		local handle = io.popen("dotnet --version")

		-- If the output is nil then report an error (this should never happen)
		if handle == nil then
			vim.health.error("error on attempting to read `dotnet --version`")
			return
		end

		-- Read the result of running `dotnet --version`
		local result = handle:read("*a")
		handle:close()

		-- Remove the newline character from the result
		local version = result.gsub(result, "\n", "")

		-- Report the version of `dotnet`
		vim.health.ok("`dotnet` found " .. version)
	end
end

return M
