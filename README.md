# HUDViewWatch
November 2026
Stuart Rankin

HUDViewWatch merges two apps into one, for iPhone and Apple Watch:

- **HUDViewUI** (UIKit): a camera view with a horizon line, a compass bar and points of interest (POIs) drawn over the picture.
- **POIView2** (SwiftUI): a radar of POIs for iPhone and Apple Watch, with an editable list of places that is sent to the watch.

Everything either app could do is here, and each app's features are available to the other's code. HUDViewUI's screens were rewritten
in SwiftUI; its storyboard and view controllers were not carried over. The only UIKit left is the camera preview layer, which SwiftUI
cannot show by itself (`CameraPreview.swift`), and reading the interface orientation.

## Tabs (iPhone)
| Tab | What it does |
| :--- | :--- |
| HUD | Camera with horizon line, compass bar, heading, and the nearest places in view. Buttons: switch camera, lock the horizon, show location, open the radar. |
| Radar | Radar with range rings, a pulse at your position, pinch/slider zoom, tap to select, and a count of places in range. |
| Places | Add, edit, delete, show or hide places, including the built-in ones. Changes go to the watch. |
| Settings | Maximum range, crop to range, distance units, camera view options. |

Tapping a place on the camera view or on the radar selects it in both.

## Apple Watch
The watch shows the radar (Digital Crown zooms), the heading when no place is selected, and the place details when one is. It receives
places, hidden places, range and units from the iPhone. The radar is sized to fit every watch size.

## What came from where
| Feature | From |
| :--- | :--- |
| Camera view, horizon line, horizon lock, selfie camera | HUDViewUI |
| Compass bar (16 points), location card | HUDViewUI |
| Earth-curvature elevation, pinhole projection of places | HUDViewUI (`Shared/HUDMath.swift`, now tested) |
| Metric / imperial distances | HUDViewUI (`Shared/DistanceUnit.swift`) |
| Radar pulse and in-range count | HUDViewUI |
| Place descriptions, the extra built-in places (Danville, Redwood City, Washington DC, Work) | HUDViewUI |
| Place list, editor, map picker, edited copies of built-ins | POIView2 |
| Show/hide a place, overlap culling, range and crop settings | POIView2 |
| Watch app and WatchConnectivity sync | POIView2 |

Route waypoints from HUDViewUI are not included, as in POIView2.

## Layout
- `Shared/` is compiled for both iPhone and watch: models, store, radar, `HUDMath` (camera and horizon math), units, sync.
- `HUDViewWatch/` is iPhone only: the tabs, camera, motion, HUD screen.
- `HUDViewWatch Watch App/` is the watch screen.
- `HUDViewWatchTests/` holds the unit tests (radar, store, settings, HUD math, units).

## Requirements
iOS and watchOS 27. The user must allow location and camera. The iPhone's compass, motion sensors, GPS and camera are used.

## Testing notes
The camera, motion and compass do not exist in the Simulator. There the HUD shows a black background, a level horizon and a heading of
0°, so the places can still be seen. The projection and horizon math are covered by unit tests; the live camera view needs a real
iPhone to check.
