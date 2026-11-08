//
//  ContentView.swift
//  HUDViewWatch Watch App
//
//  Created by Stuart Rankin on 10/26/26.
//

import SwiftUI
import WatchKit

///The watch's screen: the shared radar, zoomed with the Digital Crown, showing the built-in places and the ones sent from the iPhone.
struct ContentView: View
{
    @Environment(POIStore.self) private var Store
    @Environment(RadarSettings.self) private var Settings
    ///Source of the true north heading.
    @StateObject private var Compass = HeadingProvider()
    ///Digital Crown position: 0 is fully zoomed out (800 km), 1 is fully zoomed in. Zoom is logarithmic.
    ///It starts at about 200 km (ln 0.25 / ln MinRangeRatio).
    @State private var CrownPosition: Double = 0.2314
    ///True when the arrow toggle is on: the selected place, once there is one, gets an arrow and the other places are hidden.
    @State private var IsPointing = false
    ///Points the radar is moved down, to keep it clear of the clock.
    private let TopInset = 16.0
    ///The size of the watch's screen in points. The radar is laid out on the whole screen; SwiftUI's own size for the view leaves
    ///out the safe area, which would make the radar too small.
    private let ScreenSize = WKInterfaceDevice.current().screenBounds.size

    ///The width and height of the pointing button, in points.
    private var ButtonSize: Double
    {
        ScreenSize.width * 0.18
    }

    var body: some View
    {
        //A container exactly the size of the screen, so that its lower-right corner is the screen's.
        ZStack(alignment: .bottomTrailing)
        {
            RadarContent(Places: Store.Visible, Compass: Compass, Zoom: $CrownPosition,
                         Scale: RadarFit.Scale(Available: ScreenSize, TopInset: TopInset), TopInset: TopInset, ReadoutInCorner: true,
                         IsPointing: IsPointing, UserPlaceIDs: Set(Store.Custom.map(\.id)), Unit: Settings.Unit,
                         MaxDistance: Settings.MaxDistance, BackgroundColor: Color(white: 0.2),
                         CardinalColor: Color(red: 1.0, green: 0.97, blue: 0.7))
                //Laid out on the whole screen, and sized to fit it (see `RadarFit`), so that on a small watch the cardinal letters
                //and the radar are not cut off at the screen edges.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            PointingToggle(IsOn: $IsPointing, Size: ButtonSize)
            //In from the rounded corner of the screen.
            .padding(.trailing, ScreenSize.width * 0.08)
            .padding(.bottom, ScreenSize.height * 0.08)
        }
        .frame(width: ScreenSize.width, height: ScreenSize.height)
        .ignoresSafeArea()
        //watchOS has no pinch gesture; the Digital Crown zooms (turn up to zoom in).
        .focusable()
        .digitalCrownRotation($CrownPosition, from: 0.0, through: 1.0, by: 0.02,
                              sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
    }
}

#Preview
{
    ContentView()
        .environment(POIStore())
        .environment(RadarSettings())
}
