# Godot Debug Menu

Displays performance information in a Godot project during gameplay. Inspired by
id Tech 6/7's performance overlay.

## Why use this debug menu?

- Compared to the Godot editor's Profiler, Monitors and Visual Profiler bottom
  panels, you can look at an in-game debug menu while the project is running,
  even in fullscreen if you only have a single monitor.
    - Rendering performance is highly dependent on window size, so resizing the
      window is not advised for reliable performance measurements in real world
      scenarios.
- This debug menu accurately displays graphs and best/worst frametime metrics
  over a period of the last 150 rendered frames, which is useful to diagnose
  stuttering issues. The Monitor bottom panel is only updated once a second and
  doesn't feature a 1% low FPS metric, which makes tracking stuttering
  difficult when relying solely on the monitors.
- This debug menu can be used in exported projects to reliably test performance
  without any editor interference. This includes testing on mobile and Web
  platforms, which tend to be more difficult to set up for profiling within
  Godot (if it's even possible).
- This debug menu can be used in exported projects for tech support purposes.
  For example, in a bug report, you could ask a player to upload screenshots
  with the debug menu visible to troubleshoot performance issues.

External tools such as RTSS or [MangoHud](https://github.com/flightlessmango/MangoHud)
provide some insight on how well a project actually runs. However, they lack
information on engine-specific things such as per-frame CPU/GPU time and
graphics settings.

## License

Copyright © 2023-present Hugo Locurcio and contributors

Unless otherwise specified, files in this repository are licensed under the
MIT license. See [LICENSE.md](LICENSE.md) for more information.
