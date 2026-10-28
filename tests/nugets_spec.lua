local assert = require("luassert")
local stub = require("luassert.stub")

describe("nugets", function()
	local nugets = require("projektgunnar.nugets")
	local async = require("projektgunnar.async")

	local system_stub

	local LIST_OUTPUT = table.concat({
		"Project `App` has the following package references",
		"   [net8.0]:",
		"   Top-level Package      Requested   Resolved",
		"   > Newtonsoft.Json      13.0.1      13.0.1",
		"   > Serilog              3.1.0       3.1.0",
		"",
		"   [net9.0]:",
		"   Top-level Package      Requested   Resolved",
		"   > Newtonsoft.Json      13.0.1      13.0.1",
		"   > Moq                  4.20.0      4.20.0",
		"",
	}, "\n")

	local function wait_for(pred)
		return vim.wait(1000, pred, 5)
	end

	-- Run fn inside a coroutine and return everything it returned as a list
	-- (got[1] may be nil, so check got[2] for the error)
	local function run(fn)
		local got
		async.run(function()
			got = { fn() }
		end)
		assert.is_true(wait_for(function()
			return got ~= nil
		end))
		return got
	end

	local function system_returns(obj)
		system_stub.invokes(function(_, _, on_exit)
			on_exit(obj)
		end)
	end

	before_each(function()
		system_stub = stub(vim, "system")
	end)

	after_each(function()
		system_stub:revert()
	end)

	describe("all_nugets", function()
		it("should run dotnet list <project> package with text output", function()
			system_returns({ code = 0, stdout = LIST_OUTPUT, stderr = "" })

			run(function()
				return nugets.all_nugets("proj.csproj")
			end)

			local call = system_stub.calls[1].refs
			assert.are.same({ "dotnet", "list", "proj.csproj", "package" }, call[1])
			assert.is_true(call[2].text)
		end)

		it("should return the package ids", function()
			system_returns({ code = 0, stdout = "   > Serilog   3.1.0   3.1.0\n", stderr = "" })

			local got = run(function()
				return nugets.all_nugets("proj.csproj")
			end)

			assert.are.same({ "Serilog" }, got[1])
			assert.is_nil(got[2])
		end)

		it("should list a package only once when the project targets several frameworks", function()
			system_returns({ code = 0, stdout = LIST_OUTPUT, stderr = "" })

			local got = run(function()
				return nugets.all_nugets("proj.csproj")
			end)

			assert.are.same({ "Newtonsoft.Json", "Serilog", "Moq" }, got[1])
		end)

		it("should handle windows line endings", function()
			system_returns({ code = 0, stdout = "   > A   1   1\r\n   > B   1   1\r\n", stderr = "" })

			local got = run(function()
				return nugets.all_nugets("proj.csproj")
			end)

			assert.are.same({ "A", "B" }, got[1])
		end)

		it("should return an empty list when there is no output", function()
			system_returns({ code = 0, stdout = "", stderr = "" })

			local got = run(function()
				return nugets.all_nugets("proj.csproj")
			end)

			assert.are.same({}, got[1])
			assert.is_nil(got[2])
		end)

		it("should return nil and the error when dotnet exits with a non-zero code", function()
			system_returns({ code = 1, stdout = "", stderr = "no such project" })

			local got = run(function()
				return nugets.all_nugets("proj.csproj")
			end)

			assert.is_nil(got[1])
			assert.is_truthy(got[2]:find("dotnet exited with 1", 1, true))
			assert.is_truthy(got[2]:find("no such project", 1, true))
		end)

		it("should return nil and an error when dotnet cannot be spawned", function()
			system_stub.invokes(function()
				error("ENOENT")
			end)

			local got = run(function()
				return nugets.all_nugets("proj.csproj")
			end)

			assert.is_nil(got[1])
			assert.is_truthy(got[2]:find("spawn failure", 1, true))
			assert.is_truthy(got[2]:find("ENOENT", 1, true))
		end)
	end)

	describe("outdated_nugets", function()
		it("should run dotnet list <project> package --outdated", function()
			system_returns({ code = 0, stdout = "", stderr = "" })

			run(function()
				return nugets.outdated_nugets("proj.csproj", nil)
			end)

			assert.are.same({ "dotnet", "list", "proj.csproj", "package", "--outdated" }, system_stub.calls[1].refs[1])
		end)

		it("should pass the nuget config file when one is given", function()
			system_returns({ code = 0, stdout = "", stderr = "" })

			run(function()
				return nugets.outdated_nugets("proj.csproj", "/repo/NuGet.Config")
			end)

			assert.are.same({
				"dotnet",
				"list",
				"proj.csproj",
				"package",
				"--outdated",
				"--configfile",
				"/repo/NuGet.Config",
			}, system_stub.calls[1].refs[1])
		end)

		it("should not pass --configfile for an empty config path", function()
			system_returns({ code = 0, stdout = "", stderr = "" })

			run(function()
				return nugets.outdated_nugets("proj.csproj", "")
			end)

			assert.are.same({ "dotnet", "list", "proj.csproj", "package", "--outdated" }, system_stub.calls[1].refs[1])
		end)

		it("should return each outdated package once", function()
			system_returns({ code = 0, stdout = LIST_OUTPUT, stderr = "" })

			local got = run(function()
				return nugets.outdated_nugets("proj.csproj", nil)
			end)

			assert.are.same({ "Newtonsoft.Json", "Serilog", "Moq" }, got[1])
		end)

		it("should return nil and the error when dotnet fails", function()
			system_returns({ code = 2, stdout = "", stderr = "boom" })

			local got = run(function()
				return nugets.outdated_nugets("proj.csproj", nil)
			end)

			assert.is_nil(got[1])
			assert.is_truthy(got[2]:find("dotnet exited with 2", 1, true))
		end)
	end)
end)
