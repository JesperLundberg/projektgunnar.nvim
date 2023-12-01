local api = vim.api
local M = {}
local L = {}

-- Floating result buffer
function M.open()
	local buf = api.nvim_create_buf(false, true)
	local border_buf = api.nvim_create_buf(false, true)

	api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	api.nvim_buf_set_option(buf, "filetype", "whid")

	local width = api.nvim_get_option("columns")
	local height = api.nvim_get_option("lines")

	local win_height = math.ceil(height * 0.8 - 4)
	local win_width = math.ceil(width * 0.8)
	local row = math.ceil((height - win_height) / 2 - 1)
	local col = math.ceil((width - win_width) / 2)

	local border_opts = {
		style = "minimal",
		relative = "editor",
		width = win_width + 2,
		height = win_height + 2,
		row = row - 1,
		col = col - 1,
	}

	local opts = {
		style = "minimal",
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
	}

	local border_lines = { "╔" .. string.rep("═", win_width) .. "╗" }
	local middle_line = "║" .. string.rep(" ", win_width) .. "║"
	for _ = 1, win_height do
		table.insert(border_lines, middle_line)
	end
	table.insert(border_lines, "╚" .. string.rep("═", win_width) .. "╝")
	api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

	api.nvim_open_win(border_buf, true, border_opts)
	local win = api.nvim_open_win(buf, true, opts)
	api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "' .. border_buf)

	api.nvim_win_set_option(win, "cursorline", true) -- it highlight line with the cursor on it

	-- we can add title already here, because first line will never change
	api.nvim_buf_set_lines(buf, 0, -1, false, { L.center("ProjektGunnar"), "", "" })
	-- set the header highlight
	api.nvim_buf_add_highlight(buf, -1, "PGHeader", 0, 0, -1) -- TODO: Sort out the highlights

	return win, buf -- Return window and buffer handles
end

-- Method to center a string in a window
function L.center(str)
	local width = api.nvim_win_get_width(0)
	local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
	return string.rep(" ", shift) .. str
end

-- Method to set the content of the window
function M.update(win, buf, index, total, success, command_output)
	api.nvim_buf_set_option(buf, "modifiable", true)

	-- Get the current lines in the buffer
	local current_lines = api.nvim_buf_get_lines(buf, 0, -1, false)

	-- Append the new lines
	local status_message = success and "Success" or "Failed"
	local new_lines = {
		tostring(index) .. " out of " .. tostring(total),
		"Status: " .. status_message, -- Highlight failed lines
		"Command: " .. command_output,
		"----------------------------------------",
	}
	local updated_lines = vim.list_extend(current_lines, new_lines)

	api.nvim_buf_set_lines(buf, 0, -1, false, updated_lines)

	api.nvim_buf_set_option(buf, "modifiable", false)
	api.nvim_win_set_cursor(win, { #updated_lines, 0 })
end

return M
