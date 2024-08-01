local M = {}

local map = vim.keymap.set

--- Create a popup window for user input
--- @param on_confirm function to call when user confirms input
--- @param opts table with options
--- @option opts.title string title of the popup window
function M.input_window(on_confirm, opts)
	local win = require("plenary.popup").create("", {
		title = opts.title or "",
		style = "minimal",
		borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
		relative = "cursor",
		borderhighlight = "NotisNisseBorder",
		titlehighlight = "NotisNisseTitle",
		focusable = true,
		width = 25,
		height = 1,
		line = "cursor+2",
		col = "cursor-1",
	})

	vim.cmd("normal A")
	vim.cmd("startinsert")

	map({ "i", "n" }, "<Esc>", "<cmd>q<CR>", { buffer = 0 })

	map({ "i", "n" }, "<CR>", function()
		local input = vim.trim(vim.fn.getline("."))
		vim.api.nvim_win_close(win, true)

		on_confirm(input)

		vim.cmd.stopinsert()
	end, { buffer = 0 })
end

return M
