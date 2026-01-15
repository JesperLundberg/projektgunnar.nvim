local api = vim.api

local M = {
	input = {},
	result = {},
}

-- Return drawable editor size (accounts for cmdheight/tabline properly)
local function editor_size()
	local ui = api.nvim_list_uis()[1]
	if ui then
		return ui.width, ui.height
	end
	return vim.o.columns, vim.o.lines
end

--- Calculate centered window position and size for given content width/height
--- @param width integer content width
--- @param height integer content height
--- @return {width: integer, height: integer, row: integer, col: integer}
local function centered_opts(width, height)
	local columns, lines = editor_size()
	local win_width = math.max(1, math.floor(width))
	local win_height = math.max(1, math.floor(height))
	local row = math.floor((lines - win_height) / 2)
	local col = math.floor((columns - win_width) / 2)
	return {
		width = win_width,
		height = win_height,
		row = row,
		col = col,
	}
end

--- UTF-8 + wide-char safe centering for a single line (uses display width)
--- @param s string
local function center_line(s)
	local width = api.nvim_win_get_width(0)
	local disp = vim.fn.strdisplaywidth(s)
	local pad = math.max(0, math.floor((width - disp) / 2))
	return string.rep(" ", pad) .. s
end

--- Temporarily set modifiable, run fn, then restore original state
local function with_modifiable(buf, fn)
	local prev = vim.bo[buf].modifiable
	vim.bo[buf].modifiable = true
	local ok, err = pcall(fn)
	vim.bo[buf].modifiable = prev
	if not ok then
		error(err)
	end
end

--- Replace buffer lines from start_idx to end (-1) with given lines
local function set_lines(buf, start_idx, lines)
	with_modifiable(buf, function()
		api.nvim_buf_set_lines(buf, start_idx, -1, false, lines)
	end)
end

--- Append lines to the end of the buffer
local function append_lines(buf, lines)
	with_modifiable(buf, function()
		local curr = api.nvim_buf_get_lines(buf, 0, -1, false)
		api.nvim_buf_set_lines(buf, 0, -1, false, vim.list_extend(curr, lines))
	end)
end

--- Open a floating window with built-in border/title (no separate border buffer)
--- @param opts table nvim_open_win config overrides (width/height/row/col required)
--- @return integer win, integer buf
local function open_float(opts)
	local buf = api.nvim_create_buf(false, true)

	-- Buffer options for ephemeral scratch behavior
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "projektgunnar"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.bo[buf].buflisted = false
	vim.bo[buf].modifiable = false
	vim.bo[buf].readonly = false

	-- Open the floating window
	local win = api.nvim_open_win(
		buf,
		true,
		vim.tbl_extend("force", {
			style = "minimal",
			relative = "editor",
			border = "rounded",
			title = opts.title or "",
			title_pos = "center",
			noautocmd = true,
			zindex = 200,
			width = opts.width,
			height = opts.height,
			row = opts.row,
			col = opts.col,
		}, opts)
	)

	-- Window-local cosmetics
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].cursorline = false
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].wrap = false
	vim.wo[win].list = false
	vim.wo[win].winblend = 0

	return win, buf
end

--- Keep a window centered when the UI resizes
--- @param win integer
--- @param width integer
--- @param height integer
local function recenter_on_resize(win, width, height)
	local aug = api.nvim_create_augroup("projektgunnar_recenter_" .. tostring(win), { clear = true })
	api.nvim_create_autocmd("VimResized", {
		group = aug,
		callback = function()
			if not api.nvim_win_is_valid(win) then
				return
			end
			local c = centered_opts(width, height)
			pcall(api.nvim_win_set_config, win, {
				relative = "editor",
				row = c.row,
				col = c.col,
				width = c.width,
				height = c.height,
			})
		end,
	})
end

-- Active spinner state (only present while running)
--   spinners[buf] = { timer = uv_timer, idx = int, line = int }
local spinners = {}

-- Remember the last spinner line even after stopping (for clean stripping)
--   last_spinner_line[buf] = int
local last_spinner_line = {}

local spinner_chars = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

-- Safe, idempotent timer close
local function safe_close_timer(t)
	if not t then
		return
	end
	pcall(function()
		t:stop()
	end)
	local ok, closing = pcall(function()
		return t:is_closing()
	end)
	if ok and closing then
		return
	end
	pcall(function()
		t:close()
	end)
end

---@diagnostic disable: need-check-nil
local function spinner_start(buf, interval_ms)
	-- If a spinner is already running for this buffer, do nothing
	if spinners[buf] and spinners[buf].timer then
		return
	end

	-- Allocate a dedicated line *after* current content and ensure it exists
	local curr = api.nvim_buf_get_lines(buf, 0, -1, false)
	local spinner_line = #curr + 1
	with_modifiable(buf, function()
		api.nvim_buf_set_lines(buf, spinner_line - 1, spinner_line - 1, false, { "" })
	end)

	local timer = vim.uv.new_timer()
	if not timer then
		return
	end

	local idx = 1
	timer:start(
		0,
		interval_ms or 80,
		vim.schedule_wrap(function()
			if not api.nvim_buf_is_valid(buf) then
				-- Buffer gone; stop and clear state
				if spinners[buf] then
					last_spinner_line[buf] = spinners[buf].line or last_spinner_line[buf]
				end
				safe_close_timer(timer)
				spinners[buf] = nil
				return
			end

			-- Update only the dedicated spinner line
			with_modifiable(buf, function()
				local line = api.nvim_buf_get_lines(buf, spinner_line - 1, spinner_line, false)[1] or ""
				-- Strip previous spinner glyph + optional space on this line only
				local stripped = line:gsub("^[%z\1-\127\194-\244][\128-\191]*%s?", "")
				api.nvim_buf_set_lines(buf, spinner_line - 1, spinner_line, false, {
					spinner_chars[idx] .. " " .. stripped,
				})
			end)

			idx = (idx % #spinner_chars) + 1
		end)
	)

	spinners[buf] = { timer = timer, idx = 1, line = spinner_line }
	last_spinner_line[buf] = spinner_line

	-- Auto-stop on wipe
	api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			local s = spinners[buf]
			if s then
				last_spinner_line[buf] = s.line or last_spinner_line[buf]
			end
			if s and s.timer then
				safe_close_timer(s.timer)
			end
			spinners[buf] = nil
		end,
	})
end
---@diagnostic enable: need-check-nil

local function spinner_stop(buf)
	local s = spinners[buf]
	if not s then
		return
	end
	last_spinner_line[buf] = s.line or last_spinner_line[buf]
	safe_close_timer(s.timer)
	spinners[buf] = nil
end

--- Open a centered one-line input popup (title in border; buffer is editable)
--- @param on_confirm fun(text: string)
--- @param opts? { title?: string, width?: integer }
function M.input.open(on_confirm, opts)
	opts = opts or {}
	local title = opts.title or ""
	local width = opts.width or 25

	-- One content line for typing; title lives in border
	local input_height = 1
	local c = centered_opts(width, input_height)

	local win, buf = open_float({
		width = c.width,
		height = c.height,
		row = c.row,
		col = c.col,
		title = title,
	})

	recenter_on_resize(win, c.width, c.height)

	-- Initialize the buffer with a single empty line and make it editable
	set_lines(buf, 0, { "" })
	vim.bo[buf].modifiable = true
	vim.bo[buf].readonly = false

	-- Focus the input line and enter insert mode
	api.nvim_set_current_win(win)
	api.nvim_win_set_cursor(win, { 1, 0 })
	vim.schedule(function()
		vim.cmd("startinsert")
	end)

	-- Close helpers (guard double-close)
	local closed = false
	local function close_win()
		if closed then
			return
		end
		closed = true
		if api.nvim_win_is_valid(win) then
			pcall(api.nvim_win_close, win, true)
		end
	end

	-- Close on BufLeave (transient UI behavior)
	api.nvim_create_autocmd("BufLeave", {
		buffer = buf,
		once = true,
		callback = close_win,
	})

	local kmopts = { buffer = buf, silent = true, noremap = true, nowait = true, desc = "ProjektGunnar input" }

	vim.keymap.set({ "i", "n" }, "<Esc>", close_win, kmopts)
	vim.keymap.set({ "i", "n" }, "<C-c>", close_win, kmopts)
	vim.keymap.set("n", "q", close_win, kmopts)

	vim.keymap.set({ "i", "n" }, "<CR>", function()
		local line = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
		line = vim.trim(line)
		close_win()
		pcall(on_confirm, line)
		pcall(vim.cmd.stopinsert)
	end, kmopts)

	return buf
end

-- ======================
-- Public API: Result window
-- ======================

-- Number of header lines written at the top of the result buffer
local RESULT_HEADER_LINES = 3

--- Open a large centered result window (80% of editor)
--- @return integer buf
function M.result.open()
	local columns, lines = editor_size()
	local w = math.ceil(columns * 0.8)
	local h = math.ceil(lines * 0.8 - 2)
	local c = centered_opts(w, h)

	local win, buf = open_float({
		width = c.width,
		height = c.height,
		row = c.row,
		col = c.col,
		title = "ProjektGunnar",
	})

	recenter_on_resize(win, c.width, c.height)

	-- Header/help text (no duplicate title in buffer)
	set_lines(buf, 0, {
		center_line("Close window with 'q'"),
		"",
		"",
	})

	-- Close with 'q' (stop spinner first), then close the window
	local kmopts = { buffer = buf, silent = true, noremap = true, nowait = true, desc = "Close result window" }
	vim.keymap.set("n", "q", function()
		spinner_stop(buf)
		if api.nvim_win_is_valid(win) then
			pcall(api.nvim_win_close, win, true)
		end
	end, kmopts)

	-- Also close on BufLeave
	api.nvim_create_autocmd("BufLeave", {
		buffer = buf,
		once = true,
		callback = function()
			spinner_stop(buf)
			if api.nvim_win_is_valid(win) then
				pcall(api.nvim_win_close, win, true)
			end
		end,
	})

	return buf
end

--- Print a single message (replaces content area below header)
--- @param buf integer
--- @param msg string
function M.result.print(buf, msg)
	-- Replace from first content line after header
	set_lines(buf, RESULT_HEADER_LINES, { msg, "----------------------------------------" })
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

--- Append a result block for one command (no highlights)
--- @param buf integer
--- @param index integer
--- @param total integer
--- @param success boolean
--- @param cmd string
--- @param package string
function M.result.update(buf, index, total, success, cmd, package)
	local status_symbol = success and "" or ""
	local status_message = success and "Success" or "Failed"
	append_lines(buf, {
		tostring(index) .. " out of " .. tostring(total),
		"Status: " .. status_message .. " " .. status_symbol,
		"Package: " .. package,
		"Command: " .. cmd,
		"----------------------------------------",
	})
end

--- Start the spinner (allocates a dedicated line below current content)
--- @param buf integer
function M.result.spinner(buf)
	spinner_start(buf, 80)
end

--- Clear spinner and remove its dedicated line entirely
--- @param buf integer
function M.result.clear_spinner(buf)
	-- Stop the timer if running
	spinner_stop(buf)

	-- Find the spinner line (prefer active state, fall back to last known)
	local line = (spinners[buf] and spinners[buf].line) or last_spinner_line[buf]
	if not line then
		-- Nothing to remove
		return
	end

	-- Remove the line completely so the next content starts at the same index
	with_modifiable(buf, function()
		api.nvim_buf_set_lines(buf, line - 1, line, false, {})
	end)

	-- Clear saved pointer
	last_spinner_line[buf] = nil
end

--- Append a final "Done!" block, stopping/stripping spinner first
--- @param buf integer
function M.result.done(buf)
	-- Ensure spinner is stopped and glyph is stripped on its line
	M.result.clear_spinner(buf)
	append_lines(buf, { "Done!", "----------------------------------------" })
end

return M
