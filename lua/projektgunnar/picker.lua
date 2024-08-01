local picker = require("mini.pick")

local M = {}

local chosen_item = nil

--- Present user with a list of choices and return the choice
--- @param prompt string the prompt to show the user
--- @param items table the items to choose from
--- @return string
function M.ask_user_for_choice(prompt, items)
	local mini_pick_config = {
		-- This is a bit of a hack
		-- Set the prompt as the prefix to the prompt
		window = {
			prompt_prefix = prompt .. "> ",
		},
		source = { items = items },
	}

	-- Start the picker
	chosen_item = picker.start(mini_pick_config)

	-- Return the chosen items
	return chosen_item
end

return M
