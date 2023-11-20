# projektgunnar.nvim

Gunnar is the nice old man who helps you add projects or packages to dotnet solutions so you can take a Fika(tm) instead of having to remember how to do the different dotnet commands.

#### Why?

> [!NOTE]
> This is a work in progress and while it is almost feature complete it is far from done. I have more ideas on what I want to add but first and foremost I need to make it look good. Right now it is very bare bones on the UI side.

Everytime I wanted to add nugets, references to other projects or add a project to the solution I had to spend some time getting the dotnet commands right. It started to annoy me and so the idea of a plugin was born. This is a plugin that helps with those commands and allows you to run them from inside neovim without using a terminal.

#### Required system dependencies

`dotnet` must be installed and in the path.
Install it using the way your OS allows.

For Arch Linux the command is `pacman -S dotnet-sdk`.

#### How to install

Using lazy package manager:

```lua
"JesperLundberg/projektgunnar.nvim"
```

#### Available commands

| Command | Description |
| --- | --- |
| AddProjectReference | Adds a project reference of one project to another |
| AddPackagesToProject | Add a nuget package to a project |
| UpdatePackagesInSolution | Update all nuget packages in the chosen project |

#### TODO

- [ ] Add project to solution functionality
- [ ] Make result show up in a floating buffer
- [ ] Use some kind of picker to choose in the list of projects (telescope? mini.pick?)
- [ ] Add some kind of progress buffer when updating all nugets
- [ ] Make sure directory.packages.config works, also make sure it works without that file
- [ ] Make UpdatePackagesInSolution really update all packages in the solution
- [ ] Make another command called UpdatePackagesInProject that updates all packages in the chosen project
- [ ] Make the command ProjektGunnar and instead take e.g. AddProjectReference as input to avoid clogging up the commands
