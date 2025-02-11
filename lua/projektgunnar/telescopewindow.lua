local M = {}

---@param options string[]
---@param callback fun(integer)
function M.createTelescopeWindow(options, callback)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values

    print(options)

    local max_height = 40
    local height = math.min(#options * 5, max_height)
    pickers
        .new({}, {
            prompt_title = "Select an Option",
            finder = finders.new_table({
                results = options,
            }),
            sorter = conf.generic_sorter({}),
            layout_strategy = "center",
            layout_config = {
                width = 80,
                height = height,
                prompt_position = "bottom",
            },
            attach_mappings = function(_, map)
                map("i", "<CR>", function(prompt_bufnr)
                    local selection = require("telescope.actions.state").get_selected_entry()
                    require("telescope.actions").close(prompt_bufnr)
                    callback(selection.index)
                end)
                return true
            end,
        })
        :find()
end

return M
