# DOTSYS

### Share and manage your dotfiles and packages together!

This system is based on the topic-centric concept introduced by Zach Holman.  If 
you are using this system and are familiar with package mangers like brew..

### Yoy already know how to use it!

NOTE: A repo is any github repository containing topic-centric dotfiles

Setup a new machine from a remote repo:
> dotsys install github_user/repo_name

Try a new .vimrc:
> dotsys install vim from github_user/repo_name

Add a new topic to your local config:
> dotsys install tmux

Update all local & remote data (package managers, changes to bash config, etc):
> dotsys update

Upgrade your software:
> dotsys upgrade vim

Sync a local repo with remote (auto push or pull)
> dotsys upgrade repo

Remove a topic's changes from your system (topic files remain):
> dotsys uninstall vim

Remove all changes from a repo you tried:
> dotsys uninstall github_user/repo_name

Remove dotsys and all changes ever made to your system:
> dotsys uninstall

### Why another dotfile management system ?

- One configuration for multiple platforms (osx, windows, linux, freebsd, mysys, babun, and more).
- Supports all posix compliant shells (NO DEPENDENCIES).
- Separates packages and dotfiles form the management system.
- Nothing happens without your consent or ride hands free! 
- Separate tasks so users can select what they want.
- Guided configuration (no docs or code to read).
- Easy control over your config with yaml files.
- Constant visual feedback on what's hapening.
- Automates repository install and management.
- Automate boiler plate stuff with stub files.
- Dependency management for dotfiels.
- Easy and familiar api.
- MANY MORE FEATURES....

more info to come, stay tuned...

### WARNING!

THIS IS A WORK IN PROGRESS AND IS NOT SUFFICIENTLY TESTED!
The api could change and things could break at any time.

If you are interested in helping out that would be awesome!


## Installation 

### all but windows

1) Place the extracted repo ".dotsys" in the directory you want to install it (your dotfiles directory is a great choice)
2) From your shell of choice run the install script:
> path/to/.dotsys/install.sh

Then just follow the prompts in your termnal.

### Windows
If you want to use babun use command prompt to execute:
> path/to/.dotsys/install.bat

Otherwise install your posix shell of choice and follow the (all but windows) instructions.







