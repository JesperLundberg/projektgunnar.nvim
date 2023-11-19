# projektgunnar.nvim

Gunnar is the nice old man who helps you add projects or packages to dotnet solutions so you can take a Fika(tm) instead of having to remember how to do the different dotnet commands.

#### Why?

Note: This is a work in progress and while it is almost feature complete it is far from done. I have more ideas on what I want to add but first and foremost I need to make it look good. Right now it is very bare bones on the UI side.

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
