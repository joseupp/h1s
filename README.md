# H1s: A Call of Duty®: Modern Warfare® Remastered Modded Offline Client

H1s is a client modification based on [H1-Mod][h1mod-link] to play Modern Warfare Remastered multiplayer offline against bots, with public matches that feel as if real players were in them.

It is the result of a joint effort between [joseupp](https://github.com/joseupp) and **Claude** (Anthropic's AI).

**NOTE**: You must legally own [Call of Duty®: Modern Warfare® Remastered](https://store.steampowered.com/app/393080/) on Steam to run this mod. The game will not start if your account does not own it. Cracked/Pirated versions of the game are **NOT** supported.

Current version: **r1000b** (beta).

## Features

- Offline public lobby: bots join the lobby like real players.
- Change the game mode, options, map and bots from Game Setup in the lobby.
- Free-for-all modes default to 8 players (7 bots + you).
- Map vote like the original public matches: maps rotate between matches and bots vote too. Pick a map in Game Setup to keep it.
- DLC maps you don't have installed are hidden.
- Menus use the game's own localized strings ("Local match"), so they follow the game language.
- Featured panel in the main menu with local content (`h1s\marketing`).
- Custom textures: images in `h1s\images` replace the game ones with the same name.
- Starts straight into multiplayer, without launcher or external console window.
- Everything in the game folder (`h1s`): AppData is not used.
- Offline only.

## Installation

Download the latest `h1s-rXXXXb.zip` from [Releases](https://github.com/joseupp/h1s/releases).

Required files:
```
├── h1s.exe
└── h1s/
    └── (useful files)
```

Move all files to your Call of Duty®: Modern Warfare® Remastered game folder.

The first time, open Steam with your account and run `h1s.exe`.

## Build

- Install [Visual Studio 2022][vs-link] and enable `Desktop development with C++`
- Clone this repository using [Git][git-link]. **Do not download it as a ZIP**, as it would not include the dependencies.
- Run `generate.bat` (updates the submodules and generates the solution with Premake)
- Build the project via the solution file in `build\h1s.sln`, or run `build.ps1` to build Release x64 from the command line

The output executable is `h1s.exe`. Only x64 is supported. The `h1s` folder of the release is `data\h1s` in this repository.

## Credits

- **[joseupp](https://github.com/joseupp) and Claude (Anthropic)**: H1s.
- [H1-Mod][h1mod-link] (AuroraMod): the client it is based on.
- [s1-mod](https://git.alterware.dev/alterware/s1-mod), [h2-mod](https://github.com/alicealys/h2-mod) and [momo5502](https://github.com/momo5502): codebase and research.

## Disclaimer

This software has been created purely for the purposes of
academic research. It is not intended to be used to attack
other systems. Project maintainers are not responsible or
liable for misuse of the software. Use responsibly.
Not affiliated with Activision or Infinity Ward. Licensed under GPL-3.0 (see `LICENSE`).

[h1mod-link]:             https://github.com/auroramod/h1-mod
[git-link]:               https://git-scm.com
[vs-link]:                https://visualstudio.microsoft.com/vs
