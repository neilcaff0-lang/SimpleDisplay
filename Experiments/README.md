# Experimental 120 Hz build

Default remains 60 Hz. Request and persistence ceilings share 120 Hz.
Create a new display at 120 Hz; do not reconfigure your sole existing main display.
The stock v1.6.6 reconfigure path recreates a display and is not changed here.

RefreshProbe.m is a standalone timed probe using the existing bridge, unique process-owned display identity, and no saved app state. It only selects a mode on the display it created, aborts if the original main display changes, measures display-link callbacks for 12 seconds and removes its own display on exit. It does NOT prove unique composited frames or remote 120 fps.

Compile on macOS without editing any source:
```sh
clang -fobjc-arc -fblocks -I Sources/VirtualDisplayBridge/include Experiments/RefreshProbe.m Sources/VirtualDisplayBridge/VirtualDisplayWrapper.m -framework Foundation -framework CoreGraphics -framework CoreVideo -framework QuartzCore -o RefreshProbe
./RefreshProbe 1512 982 1 120
```
