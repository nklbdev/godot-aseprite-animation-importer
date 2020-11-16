# Aseprite Animation Importer

This is a plugin for [Godot Engine](https://godotengine.org) to import
animations into `SpriteFrames` resource from the [Aseprite](https://www.aseprite.org/).

<img width="720" alt="aseprite_screenshot" src="https://user-images.githubusercontent.com/7024016/99195066-4b384c80-27a5-11eb-9247-e5a9b1f238eb.png">
<img width="720" alt="godot_screenshot" src="https://user-images.githubusercontent.com/7024016/99195092-6e62fc00-27a5-11eb-8322-0c1535371884.png">

Screencast:

[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/0UvCWu-14Zg/0.jpg)](https://www.youtube.com/watch?v=0UvCWu-14Zg)

## Installation

Simply download it from Godot Asset Library: https://godotengine.org/asset-library/asset/767.

Alternatively, download or clone this repository and copy the contents of the
`addons` folder to your own project's `addons` folder.

Then enable the plugin on the Project Settings.

## Features

* Import Aseprite file as `SpriteFrames` resource. Each tag in Aseprite is a `SpriteFrames` animation.
* Get frame duration to calculate animation speed from first frame of each tag.

* Not recommended for large files (high resolution and many frames) because Importer stores result data to compressed resource with embedded texture.

* Supports animation direction: `Forward`, `Reverse` and `Ping-pong`
* Supports inner padding of each frame to avoid distortions on edges
* Supports looped animations for tags that names from underscore ("_")
* Checks duplicated and empty tag names
* Correctly updates cached resource currently loaded in editor (but if you keep open Sprite Frames animation tool, you have errors that go away after Godot restart)

## Usage (once the plugin is enabled)

1. Go to Project -> Project Settings -> Aseprite Animation Importer and pecify Aseprite Executable Path
2. Place your Aseprite files inside your project
3. PROFIT!

The resource can be used as `Frames` property value for `AnimatedSprite`, but you can not edit it's animations it in Godot.
If you need to make changes, change Aseprite file directly

If the file can't be imported, an error message will be generated in the output.
Please check the output if you are having an issue.

## License

[MIT License](LICENSE). Copyright (c) 2020 Nikolay Lebedev.