# Debug Menu add-on demo project for Godot 4.x

**Displays performance information in a Godot project during gameplay.**
Can be used when running from the editor and in exported projects.
Inspired by id Tech 6/7's performance overlay.

![Screenshot](https://raw.githubusercontent.com/Calinou/media/master/godot-debug-menu-demo/screenshot.png)

This repository contains the demo project for the
[Debug Menu add-on](https://github.com/godot-extended-libraries/godot-debug-menu).
The add-on's code is included in this repository and is mirrored periodically.

Please report issues specific to the add-on
[here](https://github.com/godot-extended-libraries/godot-debug-menu), not in this repository.

## Try it out

> **Note**
>
> This add-on only supports Godot 4.x, not Godot 3.x.

### Using the Asset Library

- Open the Godot project manager.
- Navigate to the **Templates** tab and search for "debug menu".
- Install the [*Debug Menu Demo*](https://godotengine.org/asset-library/asset/1903) project.

### Manual installation

Manual installation lets you try pre-release versions of this demo by following its
`master` branch.

- Clone this Git repository:

```bash
git clone https://github.com/godot-extended-libraries/godot-debug-menu-demo.git
```

Alternatively, you can
[download a ZIP archive](https://github.com/godot-extended-libraries/godot-debug-menu-demo/archive/master.zip)
if you do not have Git installed.

- Import the Godot project using the project manager and open it in the editor.
- Run the main scene by pressing <kbd>F5</kbd>.

## Usage

- Press <kbd>F3</kbd> while the project is running. This cycles between no debug
  menu, a compact debug menu (only FPS and frametime visible) and a full debug
  menu.

## License

Copyright © 2023-present Hugo Locurcio and contributors

Unless otherwise specified, files in this repository are licensed under the
MIT license. See [LICENSE.md](LICENSE.md) for more information.
