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
		local function cursor_to(text)
			for i, l in ipairs(lines()) do
				if l:find(text, 1, true) then
					vim.api.nvim_win_set_cursor(0, { i, 0 })
					return
				end
			end
		end

		it("should show a failed command collapsed with its output hidden", function()
			ui.result.update(buf, false, "dotnet add p package Foo", "Foo", { "error: boom", "second" })

			assert.is_true(has_line("▸ Foo", true))
			assert.is_false(has_line("    error: boom"))
			assert.is_false(has_line("    Command: dotnet add p package Foo"))
		end)

		it("should expand and collapse the output of a failed command", function()
			ui.result.update(buf, false, "dotnet add p package Foo", "Foo", { "error: boom", "second" })
			cursor_to("Foo")

			ui.result.toggle(buf, vim.api.nvim_get_current_win())
			assert.is_true(has_line("▾ Foo", true))
			assert.is_true(has_line("    Command: dotnet add p package Foo"))
			assert.is_true(has_line("    error: boom"))
			assert.is_true(has_line("    second"))

			ui.result.toggle(buf, vim.api.nvim_get_current_win())
			assert.is_true(has_line("▸ Foo", true))
			assert.is_false(has_line("    error: boom"))
		end)

		it("should not be expandable for a failed command without output", function()
			ui.result.update(buf, false, "dotnet add p package Foo", "Foo", {})
			cursor_to("Foo")
			local before = lines()

			ui.result.toggle(buf, vim.api.nvim_get_current_win())

			assert.is_false(has_line("▸ Foo", true))
			assert.are.same(before, lines())
		end)

		it("should not be expandable for a successful command", function()
			ui.result.update(buf, true, "dotnet add p package Foo", "Foo", { "ignored" })
			cursor_to("Foo")
			local before = lines()

			ui.result.toggle(buf, vim.api.nvim_get_current_win())

			assert.are.same(before, lines())
			assert.is_false(has_line("    ignored"))
		end)

		it("should keep following the right line after expanding an earlier block", function()
			ui.result.update(buf, false, "cmd1", "Foo", { "boom" })
			ui.result.update(buf, false, "cmd2", "Bar", { "bang" })
			cursor_to("Foo")

			ui.result.toggle(buf, vim.api.nvim_get_current_win())
			cursor_to("Bar")
			ui.result.toggle(buf, vim.api.nvim_get_current_win())

			assert.is_true(has_line("▾ Foo", true))
			assert.is_true(has_line("▾ Bar", true))
			assert.is_true(has_line("    bang"))
		end)
	end)

	describe("progress", function()
		it("should say which project is being processed when there are several", function()
			ui.result.progress(buf, 2, 5, "Api")

			assert.is_true(has_line("Project 2 out of 5: Api"))
		end)

		it("should only show the project name when there is one project", function()
			ui.result.progress(buf, 1, 1, "Api")

			assert.is_true(has_line("Project: Api"))
		end)
	end)

	describe("when the buffer has been wiped", function()
		it("should not raise errors from any result function", function()
			vim.api.nvim_buf_delete(buf, { force = true })

			assert.has_no.errors(function()
				ui.result.print(buf, "hello")
				ui.result.progress(buf, 1, 2)
				ui.result.update(buf, false, "cmd", "pkg", { "x" })
				ui.result.spinner(buf)
				ui.result.clear_spinner(buf)
				ui.result.done(buf)
			end)
		end)
	end)
end)
