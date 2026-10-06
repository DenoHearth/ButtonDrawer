# Button Drawer

One minimap button that holds every addon's minimap button and folds them out on click. Includes a Lua error button.

[![Latest release](https://img.shields.io/github/v/release/DenoHearth/ButtonDrawer?label=download&style=for-the-badge)](https://github.com/DenoHearth/ButtonDrawer/releases/latest)

A World of Warcraft: Forever addon (interface 16001).

## What it does

Addon minimap buttons are taken off the minimap and parked in a drawer behind a single
button. Click that button and they fold out in a grid; click it again and they fold back
in. The drawer stays open until you close it.

- **One button instead of many.** Collects LibDBIcon buttons and most hand-made minimap
  buttons (any named child of the minimap whose name looks like a minimap button).
  Blizzard's own minimap controls are left alone.
- **Buttons stay put.** When an addon tries to move its button back onto the minimap,
  Button Drawer puts it back in the drawer.
- **Built-in Lua error button.** The first cell of the drawer is an error button: grey
  when there are no errors, red with a count when there are. The count also shows as a
  badge on the drawer button. Errors are deduplicated and kept in a window with copyable
  text (Select all / Clear / Close). It replaces the default error popup.
- **Movable.** Drag the drawer button around the minimap; the position is saved.
- **Standalone.** No libraries, no dependencies.

## Install

- **CurseForge:** [Button Drawer](https://www.curseforge.com/wow/addons/button-drawer),
  or search for it in the CurseForge app under WoW: Forever.
- **By hand:** download the zip from the
  [latest release](https://github.com/DenoHearth/ButtonDrawer/releases/latest) and extract
  the `ButtonDrawer` folder into `World of Warcraft\<Forever folder>\Interface\AddOns\`.
  Restart the game.

## Use

| Action | Result |
|---|---|
| Left-click the drawer button | Open or close the drawer |
| Right-click the drawer button | Open the Lua error window |
| Drag the drawer button | Move it around the minimap |

## Commands

- `/bd` or `/buttondrawer` - open or close the drawer
- `/bd columns N` - buttons per row
- `/bd ignore NAME` - leave one button on the minimap (run it again to take it back)
- `/bd list` - list the collected buttons by name
- `/bd errors` - open the Lua error window
- `/bd reset` - restore defaults

## Files

- `Core.lua` - finding, adopting and laying out minimap buttons; the drawer; commands
- `Errors.lua` - the error catcher and its window

## Limits

- Protected and forbidden frames are never touched, so a button the game locks stays where
  it is.
- A button with an unusual name may be missed; `/bd list` shows what was collected.


## Compatibility

- World of Warcraft: Forever, interface version **16001**.
- Forever only. It uses that client's API and will not load on retail or the Classic clients.

## Changelog

What changed in each version: [CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE).  Current version: 1.0.0.
