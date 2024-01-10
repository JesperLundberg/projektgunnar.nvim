# projektgunnar.nvim

Gunnar is the nice old Swedish man who helps you add projects or packages to dotnet solutions so you can take a Fika(tm) instead of having to remember how to do the different dotnet commands.

#### Demo

![Demo](https://github.com/JesperLundberg/projektgunnar.nvim/assets/4082519/827ac4be-9e47-42bd-a015-88e08d3a1f4a)

#### Why?

> [!NOTE]
> This is a work in progress.

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
    "echasnovski/mini.pick",
    "echasnovski/mini.notify",
},
```

> [!ERROR]
> At the moment mini.notify overwrites any existing notification plugin. It's on the list to make sure mini.notify is optional and if used then it is unloaded after plugin is done with it's work.

#### Available commands

| Command                | Description                                      |
| ---------------------- | ------------------------------------------------ |
| AddNugetToProject      | Add a nuget package to a project                 |
| UpdateNugetsInProject  | Update all nuget packages in the chosen project  |
| UpdateNugetsInSolution | Update all nuget packages in the chosen solution |
| AddProjectToProject    | Add a project as reference in another            |
| AddProjectToSolution   | Add a project to the solution file               |

#### TODO

- [x] Make another command called UpdatePackagesInProject that updates all packages in the chosen project
- [x] Make result show up in a floating window
- [x] Add some kind of progress buffer when updating all nugets
- [x] Add project to project functionality
- [x] Use some kind of picker to choose in the list of projects (telescope? mini.pick?)
- [x] Make sure directory.packages.config works, also make sure it works without that file
- [x] Add symbols for success/failed command
- [x] Add project to solution functionality
- [x] Use mini.notify to give messages to user
- [x] Make mini.notify optional or make sure it's unloaded after each run as it takes over messages otherwise

#### Credits

[Issafalcon](https://github.com/Issafalcon/) - for being patient with questions and giving me clues on what to look into.

[echasnovski](https://github.com/echasnovski) - for creating the mini library and in this case mini.pick which I am using here.
