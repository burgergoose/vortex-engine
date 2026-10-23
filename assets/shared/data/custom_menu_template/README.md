# Custom menus (Vortex Engine 0.5+)

This folder changes how Vortex Engine's menus look, with no code. Players turn it on in
**Developer menu (7 on the main menu) -> Menu Editor -> Custom Theme**, or it turns on by itself
when `"autoApply": true` and the player hasn't picked a theme yet.

```
mods/<YourMod>/custom_menus/
    menu.json      settings (this file's neighbour)
    assets/        pictures (PNG) and fonts (TTF / OTF) used by menu.json
    animations/    animated pictures: name.png + name.xml (Sparrow sheet, like characters)
    README.md      this file
```

The Menu Editor can also edit the most-used settings, shows a preview and lists any problems.
If menu.json has an error, Vortex uses its built-in theme instead and the error is shown in the
Menu Editor and written to `vortex_script_log.txt`.

## menu.json

Every setting is optional. Leave one out to keep the Vortex default.

| Setting | What it does |
|---|---|
| `format` | Always `1`. |
| `name`, `author` | Shown in the Menu Editor. |
| `autoApply` | `true`: used automatically until the player picks a theme in the Menu Editor. |
| `font` | A `.ttf` / `.otf` in `assets/` (or a font of the game, like `vcr.ttf` or `pixel-latin.ttf`). |
| `colors` | `panelFill`, `panelBorder`, `panelBorderSelected`, `accent`, `text`, `textDim`, `primary`, `secondary`, `tertiary` as `"#RRGGBB"`. Buttons cycle through primary / accent / secondary / tertiary. |
| `background` | `{"type": "cosmic"}` (Vortex), `{"type": "color", "color": "#101020"}`, `{"type": "gradient", "colors": ["#1A0F3D", "#05040D"]}` or `{"type": "image", "image": "bg.png"}`. Add `"scroll": [20, 0]` to an image to make it scroll (pixels per second), `"alpha": 0.8` to dim it, and `"animation": {...}` (see below) to put an animated picture on top. Cosmic backgrounds can turn the rings off with `"rings": false`. |
| `animations` | `"intro"`: `"slide"`, `"fade"` or `"none"` (how buttons and cards appear). `"speed"`: `1` = normal, `2` = twice as fast. |
| `transitions` | `"type"`: `"fade"` or `"none"`, `"duration"` in seconds (between screens). |
| `mainMenu` | See below. |
| `freeplay` | `title`, `showInfoPanel` (false = the song list moves to the middle), `background`. |
| `storyMode` | `title`, `background`. |
| `developerMenu` | `title`, `background`. |
| `chartEditor` | `background` (colour), `grid` and `gridOther` (two colours each). Applied when the theme is chosen. |

### mainMenu

| Setting | What it does |
|---|---|
| `title`, `subtitle` | The big title text and the line under it. |
| `logo` | A picture in `assets/` shown instead of the title (`"logo.png"`), or an animation: `{"file": "logo", "prefix": "logo bumpin", "fps": 24, "x": 40, "y": 10, "scale": 0.8}`. |
| `buttons` | `x`, `y`, `spacing`, `width` (numbers) and `align` (`"left"`, `"center"`, `"right"`). |
| `labels` | Other text on the buttons: `{"story_mode": "CAMPAIGN", "freeplay": "SONGS"}`. |
| `icons` | A picture from `assets/` on each button: `{"story_mode": "icons/story.png"}`. |
| `showInfoPanel` | `false` hides the panel on the right. |
| `infoText` | Other descriptions in that panel: `{"mods": "Add-ons for this mod."}`. |
| `navigation` | `"wrap": false` stops the selection at the top / bottom, `"mouse": false` turns mouse selection off (keys always work). |
| `showVersion` | `false` hides the version text. |
| `background` | A background just for the main menu. |

Option names: `story_mode`, `freeplay`, `mods`, `credits`, `achievements`, `options`.

### Animations

`animations/star.png` + `animations/star.xml` (exported like a character sprite sheet), used as
`{"file": "star", "prefix": "star spin", "fps": 24, "x": 1000, "y": 40, "scale": 1, "loop": true}`.

## What a custom menu can't do

It keeps every menu option and key, and the Vortex layout (buttons on the left, panels on the
right). For a completely different menu, write a state script (`states/MainMenuState.lua`) or a
custom state - see the modding docs.
