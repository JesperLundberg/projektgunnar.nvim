local assert = require("luassert")

describe("ui.result", function()
	local ui = require("projektgunnar.ui")

	local buf

	local function lines()
		return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	end

	local function has_line(text, plain_prefix)
		for _, l in ipairs(lines()) do
			if plain_prefix then
				if vim.startswith(l, text) then
					return true
				end
			elseif l == text then
				return true
			end
		end
		return false
	end

	before_each(function()
		buf = ui.result.open()
	end)

	after_each(function()
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end)

	describe("update", function()
		it("should show the output of a failed command", function()
			ui.result.update(buf, 1, 1, false, "dotnet add p package Foo", "Foo", { "error: boom", "second" })

			assert.is_true(has_line("Status: Failed", true))
			assert.is_true(has_line("Output:"))
			assert.is_true(has_line("  error: boom"))
			assert.is_true(has_line("  second"))
		end)

		it("should not show an output section for a failed command without output", function()
			ui.result.update(buf, 1, 1, false, "dotnet add p package Foo", "Foo", {})

			assert.is_true(has_line("Status: Failed", true))
			assert.is_false(has_line("Output:"))
		end)

		it("should not show output for a successful command", function()
			ui.result.update(buf, 1, 1, true, "dotnet add p package Foo", "Foo", { "ignored" })

			assert.is_true(has_line("Status: Success", true))
			assert.is_false(has_line("Output:"))
			assert.is_false(has_line("  ignored"))
		end)

		it("should keep the package and command lines", function()
			ui.result.update(buf, 2, 3, true, "dotnet add p package Foo", "Foo")

			assert.is_true(has_line("2 out of 3"))
			assert.is_true(has_line("Package: Foo"))
			assert.is_true(has_line("Command: dotnet add p package Foo"))
		end)
	end)

	describe("progress", function()
		it("should say which project is being processed", function()
			ui.result.progress(buf, 2, 5)

			assert.is_true(has_line("Project 2 out of 5"))
		end)
	end)

	describe("when the buffer has been wiped", function()
		it("should not raise errors from any result function", function()
			vim.api.nvim_buf_delete(buf, { force = true })

			assert.has_no.errors(function()
				ui.result.print(buf, "hello")
				ui.result.progress(buf, 1, 2)
				ui.result.update(buf, 1, 1, false, "cmd", "pkg", { "x" })
				ui.result.spinner(buf)
				ui.result.clear_spinner(buf)
				ui.result.done(buf)
			end)
		end)
	end)
end)
