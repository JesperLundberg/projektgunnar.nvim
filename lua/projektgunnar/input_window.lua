local M = {}

local map = vim.keymap.set

--- Create a popup window for user input
--- @param on_confirm function to call when user confirms input
--- @param opts table with options
--- @option opts.title string title of the popup window
function M.input_window(on_confirm, opts)
        local width = 25
        local height = 1

        -- Get the editor dimensions
        local ui = vim.api.nvim_list_uis()[1]
        local win_width = ui.width
        local win_height = ui.height

        -- Calculate centered position
        local row = math.floor((win_height - height) / 2)
        local col = math.floor((win_width - width) / 2)

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
                line = row,
                col = col,
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
