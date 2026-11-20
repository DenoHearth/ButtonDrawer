# Changelog

## v1.3.1 — 2026-11-20

- Set window: the "stays on the minimap" note no longer runs into the Macro button

## v1.3.0 — 2026-11-20

- Macros for your action bars: every addon in the **Set** window has a **Macro** button. It makes a macro that clicks that addon's minimap button (`/click <button>`, with the addon's own icon) and puts it on your mouse; one click on an action bar slot puts it there. Pressing it opens the addon's window like a click on its minimap button
- Two more buttons in the Set window make macros for Button Drawer's own Lua error window and Set window
- Macros are account-wide (character macros when the account list is full); pressing Macro again updates the same macro instead of making a second one. Not possible in combat

## v1.2.6 — 2026-11-20

- Goldwright's button goes into the drawer: Goldwright keeps its minimap button hidden by default (it lives in the game's add-on menu), so Button Drawer switches that button on at login and collects it

## v1.2.5 — 2026-11-08

- Dragging the minimap button: the button (and the drawer with it) no longer keeps following the mouse after you let go; the drag now stops as soon as the mouse button is up or the button is hidden
- A temporary minimap recorder from 1.2.4 is gone again, and its saved log is cleared at login

## v1.2.2 — 2026-10-19

- New **Mark All** button in the error window: every error at once, newest first, marked so one Ctrl+C copies them all. It stays marked until you press another button
- Lua errors survive a /reload: the errors from before the reload come back in the window (a fresh login still starts empty)

## v1.2.0 — 2026-10-12

- The error window shows one Lua error at a time, newest first, with **Previous** and **Next** buttons to go through them; the title says which one you are on and how often it happened. A new error arriving does not move you off the one you are reading
- The Copy button made the game report "ButtonDrawer was forbidden from calling UNKNOWN()" at every press: the game keeps the clipboard for its own UI. It is now **Mark**: it marks the error shown, and Ctrl+C copies it

## v1.1.2 — 2026-10-11

- On a square minimap (any addon that reports the minimap's shape) the drawer button sits outside the square instead of inside its corner

## v1.1.1 — 2026-10-10

- Icons in the drawer are fully lit: buttons made with LibDBIcon were drawn underneath the drawer's panel and looked greyed out, and addons that fade minimap buttons until the mouse is on the minimap (Leatrix Plus "Hide addon buttons") no longer fade them in the drawer
- A frame that is only named like a minimap button, such as another addon's own minimap, is no longer pulled into the drawer (it left an empty cell and hid that minimap)
- Manage window: a scroll bar beside the button list
- Lua errors window: a Copy button that puts the whole report on the clipboard

## v1.1.0 — 2026-10-08

- Manage window (the Set cell in the drawer, or /bd config): every button with On, Up and Down, icon size, columns, open on mouse-over; the drawer opens away from the screen edges; its button turns red while there are Lua errors

## v1.0.2 — 2026-10-06

- Collects every addon button on the minimap, not only ones with typical minimap-button names; opening the drawer rescans for late buttons.

## v1.0.1 — 2026-10-06

- The drawer is now a plain toggle: it stays open until you click the button again, instead of closing when the mouse leaves.

## v1.0.0 — 2026-10-06

- First release for WoW: Forever.
