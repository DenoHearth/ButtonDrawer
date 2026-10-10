# Changelog

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
