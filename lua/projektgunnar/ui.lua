local api = vim.api

local M = {
	input = {},
	result = {},
}

--- Create a centered rectangle in the editor
--- @param width integer window width (content area)
--- @param height integer window height (content area)
--- @return {content_opts: table, border_opts: table}
local function centered_opts(width, height)
	local columns = api.nvim_get_option_value("columns", { scope = "global" })
	local lines = api.nvim_get_option_value("lines", { scope = "global" })

	local win_width = math.max(1, math.floor(width))
	local win_height = math.max(1, math.floor(height))

	local row = math.floor((lines - win_height) / 2)
	local col = math.floor((columns - win_width) / 2)

	local border_opts = {
		style = "minimal",
		relative = "editor",
		width = win_width + 2,
		height = win_height + 2,
		row = row - 1,
		col = col - 1,
		focusable = false,
	}

	local content_opts = {
		style = "minimal",
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
		focusable = true,
	}

	return { content_opts = content_opts, border_opts = border_opts }
end

--- Open a bordered floating window pair
--- @param content_opts table
--- @param border_opts table
--- @return integer content_win, integer border_win, integer content_buf, integer border_buf
local function open_bordered_window(content_opts, border_opts)
	local content_buf = api.nvim_create_buf(false, true)
	local border_buf = api.nvim_create_buf(false, true)

	-- Make content buffer ephemeral and typed
	api.nvim_set_option_value("bufhidden", "wipe", { buf = content_buf })
	api.nvim_set_option_value("filetype", "ProjektGunnar", { buf = content_buf })

	-- Draw border box
	local w, h = content_opts.width, content_opts.height
	local border_lines = { "╔" .. string.rep("═", w) .. "╗" }
	local middle_line = "║" .. string.rep(" ", w) .. "║"
	for _ = 1, h do
		table.insert(border_lines, middle_line)
	end
	table.insert(border_lines, "╚" .. string.rep("═", w) .. "╝")
	api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)
	api.nvim_set_option_value("modifiable", false, { buf = border_buf })

	local border_win = api.nvim_open_win(border_buf, true, border_opts)
	local content_win = api.nvim_open_win(content_buf, true, content_opts)

	-- Tie lifetimes: if content buffer dies, clean up border too
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = content_buf,
		once = true,
		callback = function()
			if api.nvim_buf_is_loaded(border_buf) then
				pcall(api.nvim_buf_delete, border_buf, { force = true })
			end
			if api.nvim_win_is_valid(border_win) then
				pcall(api.nvim_win_close, border_win, true)
			end
		end,
	})

	return content_win, border_win, content_buf, border_buf
end

--- Center a string for the current window width
--- @param s string
local function center_line(s)
	local width = api.nvim_win_get_width(0)
	local shift = math.max(0, math.floor(width / 2) - math.floor(#s / 2))
	return string.rep(" ", shift) .. s
end

--- Safe append lines to a buffer (keeps previous content)
local function append_lines(buf, lines)
	api.nvim_set_option_value("modifiable", true, { buf = buf })
	local curr = api.nvim_buf_get_lines(buf, 0, -1, false)
	local out = vim.list_extend(curr, lines)
	api.nvim_buf_set_lines(buf, 0, -1, false, out)
	api.nvim_set_option_value("modifiable", false, { buf = buf })
end

--- Replace a slice of lines in a buffer
local function set_lines(buf, start_idx, lines)
	api.nvim_set_option_value("modifiable", true, { buf = buf })
	api.nvim_buf_set_lines(buf, start_idx, -1, false, lines)
	api.nvim_set_option_value("modifiable", false, { buf = buf })
end

-- UTF-8-safe spinner helpers (no Lua pattern charclass on multibyte)
local spinner_chars = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_index = 1

--- Return true if the line starts with any spinner char
local function starts_with_spinner(line)
	for _, ch in ipairs(spinner_chars) do
		if line:sub(1, #ch) == ch then
			return true, ch
		end
	end
	return false, nil
end

--- Strip a spinner prefix if present; returns (stripped_line, had_spinner)
local function strip_spinner_prefix(line)
	local ok, ch = starts_with_spinner(line)
	if ok then
		return line:sub(#ch + 1), true
	end
	return line, false
end

--- Open a centered one-line input popup
--- @param on_confirm fun(text: string)
--- @param opts? { title?: string, width?: integer }
function M.input.open(on_confirm, opts)
	opts = opts or {}
	local title = opts.title or ""
	local width = opts.width or 25

	-- If there is a title, we need 2 content lines: title + input
	local input_height = (title ~= "" and 2 or 1)

	local both = centered_opts(width, input_height)
	local win, border_win, buf = open_bordered_window(both.content_opts, both.border_opts)

	-- Prepare content lines
	if title ~= "" then
		set_lines(buf, 0, { center_line(title), "" })
	else
		set_lines(buf, 0, { "" })
	end

	-- Make buffer modifiable (set_lines sets to non-modifiable)
	api.nvim_set_option_value("modifiable", true, { buf = buf })
	api.nvim_set_option_value("readonly", false, { buf = buf })
	api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	api.nvim_set_option_value("swapfile", false, { buf = buf })
	api.nvim_set_option_value("buflisted", false, { buf = buf })

	-- Focus input line and enter insert mode
	api.nvim_set_current_win(win)
	local input_line_idx = (title ~= "" and 2 or 1)
	api.nvim_win_set_cursor(win, { input_line_idx, 0 })
	vim.schedule(function()
		vim.cmd("startinsert")
	end)

	-- Close helpers
	local function close_both()
		if api.nvim_win_is_valid(win) then
			api.nvim_win_close(win, true)
		end
		if api.nvim_win_is_valid(border_win) then
			api.nvim_win_close(border_win, true)
		end
	end

	-- <Esc>: cancel and close just these windows
	vim.keymap.set({ "i", "n" }, "<Esc>", close_both, { buffer = buf, silent = true })

	-- <CR>: confirm, call callback, close
	vim.keymap.set({ "i", "n" }, "<CR>", function()
		local line = api.nvim_buf_get_lines(buf, input_line_idx - 1, input_line_idx, false)[1] or ""
		line = vim.trim(line)
		close_both()
		pcall(on_confirm, line)
		pcall(vim.cmd.stopinsert)
	end, { buffer = buf, silent = true })

	return buf
end

--- Open a large centered result window (80% of editor)
--- @return integer buf
function M.result.open()
	local columns = api.nvim_get_option_value("columns", { scope = "global" })
	local lines = api.nvim_get_option_value("lines", { scope = "global" })
	local w = math.ceil(columns * 0.8)
	local h = math.ceil(lines * 0.8 - 4)

	local both = centered_opts(w, h)
	local win, border_win, buf = open_bordered_window(both.content_opts, both.border_opts)

	api.nvim_set_current_win(win)
	set_lines(buf, 0, { center_line("ProjektGunnar"), "", center_line("Close window with 'q'"), "", "" })

	-- Close with 'q' (only these two windows)
	vim.keymap.set("n", "q", function()
		if api.nvim_win_is_valid(win) then
			api.nvim_win_close(win, true)
		end
		if api.nvim_win_is_valid(border_win) then
			api.nvim_win_close(border_win, true)
		end
	end, { buffer = buf, silent = true })

	return buf
end

--- Print a single message (replaces content area below header)
--- @param buf integer
--- @param msg string
function M.result.print(buf, msg)
	set_lines(buf, 5, { msg, "----------------------------------------" })
end

--- Append a progress line ("Updating project X of Y")
--- @param buf integer
--- @param index integer
--- @param total integer
function M.result.progress(buf, index, total)
	append_lines(buf, {
		"Updating project " .. tostring(index) .. " out of " .. tostring(total),
		"----------------------------------------",
	})
end

--- Append a result block for one command
--- @param buf integer
--- @param index integer
--- @param total integer
--- @param success boolean
--- @param cmd string
function M.result.update(buf, index, total, success, cmd)
	local status_symbol = success and "" or ""
	local status_message = success and "Success" or "Failed"
	append_lines(buf, {
		tostring(index) .. " out of " .. tostring(total),
		"Status: " .. status_message .. " " .. status_symbol,
		"Command: " .. cmd,
		"----------------------------------------",
	})
end

--- Show/update a spinner on the last line (UTF-8 safe)
--- @param buf integer
function M.result.spinner(buf)
	api.nvim_set_option_value("modifiable", true, { buf = buf })

	local curr = api.nvim_buf_get_lines(buf, 0, -1, false)
	local sp = spinner_chars[spinner_index]
	spinner_index = (spinner_index % #spinner_chars) + 1

	if #curr == 0 then
		curr = { "" }
	end
	local last = curr[#curr]
	local stripped, had = strip_spinner_prefix(last)
	if had then
		curr[#curr] = sp .. stripped
	else
		table.insert(curr, sp .. " ")
	end

	api.nvim_buf_set_lines(buf, 0, -1, false, curr)
	api.nvim_set_option_value("modifiable", false, { buf = buf })
end

--- Remove any spinner lines (UTF-8 safe)
--- @param buf integer
function M.result.clear_spinner(buf)
	api.nvim_set_option_value("modifiable", true, { buf = buf })
	local curr = api.nvim_buf_get_lines(buf, 0, -1, false)
	local kept = {}
	for _, line in ipairs(curr) do
		local _, had = strip_spinner_prefix(line)
		if not had then
			table.insert(kept, line)
		end
	end
	api.nvim_buf_set_lines(buf, 0, -1, false, kept)
	api.nvim_set_option_value("modifiable", false, { buf = buf })
end

--- Append a final "Done!" block
--- @param buf integer
function M.result.done(buf)
	append_lines(buf, { "Done!", "----------------------------------------" })
end

return M
