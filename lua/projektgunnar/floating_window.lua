local api = vim.api

local M = {}

--- Method to center a string in a window
--- @param str string
local function center(str)
	-- Get the width of the current window
	local width = api.nvim_win_get_width(0)
	-- Calculate the shift needed to center the string
	local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
	return string.rep(" ", shift) .. str
end

--- Floating result window
--- @return number, number
function M.open()
	-- Create buffers for both windows
	local buf = api.nvim_create_buf(false, true)
	local border_buf = api.nvim_create_buf(false, true)

	-- Set the buffer to be a temporary buffer that will be deleted when it is no longer in use
	api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	api.nvim_set_option_value("filetype", "ProjektGunnar", { buf = buf })

	-- Get dimensions of neovim editor
	local width = api.nvim_get_option_value("columns", { scope = "global" })
	local height = api.nvim_get_option_value("lines", { scope = "global" })

	-- Calculate our floating window size so its 80% of the editor size
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

	-- Set border buffer lines
	local border_lines = { "╔" .. string.rep("═", win_width) .. "╗" }
	local middle_line = "║" .. string.rep(" ", win_width) .. "║"
	for _ = 1, win_height do
		table.insert(border_lines, middle_line)
	end
	table.insert(border_lines, "╚" .. string.rep("═", win_width) .. "╝")
	api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

	-- Open the border window first then the actual window
	api.nvim_open_win(border_buf, true, border_opts)
	local win = api.nvim_open_win(buf, true, opts)

	-- If the window is closed, close the border window as well
	api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "' .. border_buf)

	-- we can add title already here, because first line will never change
	api.nvim_buf_set_lines(buf, 0, -1, false, { center("ProjektGunnar"), "", "" })

	return win, buf -- Return window and buffer handles
end

--- Method to update the buffer line
function M.update_buffer_line(buf, line)
	api.nvim_buf_set_lines(buf, -2, -1, false, { line })
end

--- Method to update the floating window with a done message
--- @param win number window handle
--- @param buf number buffer handle
function M.update_with_done_message(win, buf)
	-- Make the buffer modifiable
	api.nvim_set_option_value("modifiable", true, { buf = buf })

	-- Get the current lines in the buffer
	local current_lines = api.nvim_buf_get_lines(buf, 0, -1, false)

	local new_lines = {
		"Done!",
		"----------------------------------------",
	}

	-- Add the new lines to the current lines
	local lines_to_write = vim.list_extend(current_lines, new_lines)

	-- Set the updated lines
	api.nvim_buf_set_lines(buf, 0, -1, false, lines_to_write)

	-- Make the buffer unmodifiable
	api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- Set the cursor to the last line
	api.nvim_win_set_cursor(win, { #lines_to_write, 0 })
end

--- Method to print what command will be run
--- @param win number window handle
--- @param buf number buffer handle
--- @param str string
function M.print_message(win, buf, str)
	-- Make the buffer modifiable
	api.nvim_set_option_value("modifiable", true, { buf = buf })

	-- Add delimiter under the message
	local message = { str, "----------------------------------------" }

	-- Set the message
	api.nvim_buf_set_lines(buf, 2, -1, false, message)

	-- Make the buffer unmodifiable
	api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- Set the cursor to the last line
	api.nvim_win_set_cursor(win, { #message, 2 })
end

local spinner_chars = { "*", "+", "/", "#" }
local spinner_index = 1

--- Method to show a spinner in the floating window
--- @param win number window handle
--- @param buf number buffer handle
function M.progress_spinner(win, buf)
	-- Make the buffer modifiable
	api.nvim_set_option_value("modifiable", true, { buf = buf })

	-- Get the current lines in the buffer
	local current_lines = api.nvim_buf_get_lines(buf, 0, -1, false)

	-- Find the last spinner line if it exists
	local spinner_char = spinner_chars[spinner_index]

	if #current_lines > 0 then
		local last_line = current_lines[#current_lines]

		if last_line:match("^[" .. table.concat(spinner_chars, "") .. "]") then
			-- If the last line already has a spinner, replace it
			current_lines[#current_lines] = spinner_char .. last_line:sub(2)
		else
			-- If there's no spinner yet, append a new line with the spinner
			table.insert(current_lines, spinner_char .. " ")
		end

		-- Update the buffer content
		api.nvim_buf_set_lines(buf, 0, -1, false, current_lines)
	else
		-- This should never happen, but just in case
		-- Buffer is empty, append a new line with the spinner
		api.nvim_buf_set_lines(buf, 0, -1, false, { spinner_char .. " " })
	end

	spinner_index = (spinner_index % #spinner_chars) + 1

	-- Make the buffer unmodifiable
	api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- Set the cursor to the last line
	api.nvim_win_set_cursor(win, { #current_lines, 0 })
end

--- Method to clear the spinner from the floating window
--- @param buf number buffer handle
function M.clear_spinner(buf)
	-- Make the buffer modifiable
	api.nvim_set_option_value("modifiable", true, { buf = buf })

	-- Get the current lines in the buffer
	local current_lines = api.nvim_buf_get_lines(buf, 0, -1, false)

	-- Clear spinner lines
	local new_lines = {}
	for _, line in ipairs(current_lines) do
		if not line:match("^[" .. table.concat(spinner_chars, "") .. "]") then
			table.insert(new_lines, line)
		end
	end

	-- Update the buffer content
	api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)

	-- Make the buffer unmodifiable
	api.nvim_set_option_value("modifiable", false, { buf = buf })
end

--- Method to set the content of the window
--- @param win number window handle
--- @param buf number buffer handle
--- @param index number which index we are at
--- @param total number total number of items
--- @param success boolean if the command was successful
--- @param command_output string the command that was run
function M.update(win, buf, index, total, success, command_output)
	-- Make the buffer modifiable
	api.nvim_set_option_value("modifiable", true, { buf = buf })

	-- Get the current lines in the buffer
	local current_lines = api.nvim_buf_get_lines(buf, 0, -1, false)

	local status_symbol = success and "" or ""
	local status_message = success and "Success" or "Failed"

	local new_lines = {
		tostring(index) .. " out of " .. tostring(total),
		"Status: " .. status_message .. " " .. status_symbol,
		"Command: " .. command_output,
		"----------------------------------------",
	}

	-- Add the new lines to the current lines
	local lines_to_write = vim.list_extend(current_lines, new_lines)

	-- Set the updated lines
	api.nvim_buf_set_lines(buf, 0, -1, false, lines_to_write)

	-- Make the buffer unmodifiable
	api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- Set the cursor to the last line
	api.nvim_win_set_cursor(win, { #lines_to_write, 0 })
end

--- Method to update the progress in the floating window
--- @param win number window handle
--- @param buf number buffer handle
--- @param index number which index we are at
--- @param total number total number of items
function M.update_progress(win, buf, index, total)
	-- Make the buffer modifiable
	api.nvim_set_option_value("modifiable", true, { buf = buf })

	-- Get the current lines in the buffer
	local current_lines = api.nvim_buf_get_lines(buf, 0, -1, false)

	local new_lines = {
		"Updating project " .. tostring(index) .. " out of " .. tostring(total),
		"----------------------------------------",
	}

	-- Add the new lines to the current lines
	local lines_to_write = vim.list_extend(current_lines, new_lines)

	-- Set the updated lines
	api.nvim_buf_set_lines(buf, 0, -1, false, lines_to_write)

	-- Make the buffer unmodifiable
	api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- Set the cursor to the last line
	api.nvim_win_set_cursor(win, { #lines_to_write, 0 })
end

return M
