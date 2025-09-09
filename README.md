# projektgunnar.nvim

Gunnar is the nice old Swedish man who helps you add projects or packages to dotnet solutions so you can take a Fika(tm) instead of having to remember how to do the different dotnet commands.

#### Demo

> [!note] The demo is slightly outdated.

![Demo](https://github.com/JesperLundberg/projektgunnar.nvim/assets/4082519/827ac4be-9e47-42bd-a015-88e08d3a1f4a)

#### Why?

Everytime I wanted to add nugets, references to other projects or add a project to the solution I had to spend some time getting the dotnet commands right. It started to annoy me and so the idea of a plugin was born. This is a plugin that helps with those commands and allows you to run them from inside neovim without using a terminal.

#### Required system dependencies

`dotnet` must be installed and in the path.
Install it using the way your OS allows.

For Arch Linux the command is `pacman -S dotnet-sdk`.

You also need nerdfonts patched version installed to get proper symbols.
Get fonts from [here](https://github.com/ryanoasis/nerd-fonts).

#### How to install

Using lazy package manager:

```lua
"JesperLundberg/projektgunnar.nvim",
dependencies = {
    "nvim-telescope/telescope.nvim", -- Choose either telescope...
    "nvim-mini/mini.pick", -- ...or mini.pick
},
```

#### Config

```lua
-- Default config
local defaults = {
	prefer = { "telescope", "mini" },
}

-- If you have both and want mini.pick set mini as only (or first in the list) choice

local defaults = {
	prefer = { "mini" },
}
```

#### Available commands

The way to use these commands has changed from the plugins inception.
Now there is only the `ProjektGunnar` command that is supplied with the following commands.

Example (to add nuget to project):

```
:ProjektGunnar AddNugetToProject
```

| Command                  | Description                                      |
| ------------------------ | ------------------------------------------------ |
| AddNugetToProject        | Add a nuget package to a project                 |
| RemoveNugetFromProject   | Remove a nuget package from a project            |
| UpdateNugetsInProject    | Update all nuget packages in the chosen project  |
| UpdateNugetsInSolution   | Update all nuget packages in the chosen solution |
| AddProjectToProject      | Add a project as reference in another            |
| RemoveProjectFromProject | Remove a project as reference in another         |
| AddProjectToSolution     | Add a project to the solution file               |

#### TODO

#### Local development

To run tests:

```bash
nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal.vim'}"
```

#### Credits

[Issafalcon](https://github.com/Issafalcon/) - for being patient with questions and giving me clues on what to look into.
