//
//  PhoneRadarView.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/4/26.
//

import SwiftUI

///The watch's radar on the iPhone, larger, using the phone's own compass and location. Zoom with a pinch or the slider.
struct PhoneRadarView: View
{
    @Environment(POIStore.self) private var Store
    @Environment(RadarSettings.self) private var Settings
    @Environment(PlaceSelection.self) private var Selection
    @ObservedObject var Compass: HeadingProvider
    ///Starts at about 200 km, as on the watch.
    @State private var Zoom: Double = 0.2314
    ///The radar's background: indigo, 20% darker.
    private static let Background = Color.indigo.mix(with: .black, by: 0.2)

    ///The space the radar has to fill, measured on screen.
    @State private var Available = CGSize.zero
    ///The zoom when the current pinch began; `nil` between pinches.
    @State private var PinchStart: Double? = nil

    ///The width and height of the pointer toggle, in points.
    private static let ToggleSize = 52.0

    ///Half the radar's width in units of Scale: the outer ring is 80, the cardinal letters 96 from the center and about 6 across.
    private static let ExtentPerScale = 204.0
    ///The height the radar needs in units of Scale: its width plus the readout band under it (36).
    private static let HeightPerScale = 244.0

    ///The Scale that makes the radar, cardinal letters included, nearly fill the space it is given, whatever the screen.
    var FittedScale: Double
    {
        guard Available.width > 0, Available.height > 0 else
        {
            return 1.7
        }
        return min(Available.width / PhoneRadarView.ExtentPerScale, Available.height / PhoneRadarView.HeightPerScale) * 0.98
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            RadarContent(Places: Store.Visible, Compass: Compass, Zoom: $Zoom, Scale: FittedScale,
                         CropToRange: Settings.CropToRange, IsPointing: Selection.IsPointing, ShowsCount: true, UserPlaceIDs: Set(Store.Custom.map(\.id)), Unit: Settings.Unit, CardinalWeight: .heavy,
                         MaxDistance: Settings.MaxDistance,
                         BackgroundColor: PhoneRadarView.Background, CardinalColor: Color(red: 1, green: 1, blue: 0),
                         SharedSelection: Binding(get: { Selection.SelectedID }, set: { Selection.SelectedID = $0 }))
                //Markers outside the rings are cut off at the status bar above and just above the slider below. This region runs
                //from the bottom of the status bar to the top of the slider bar, so it includes the band where the annotation appears.
                .clipped()
                //The same toggle as on the watch, in the lower-right corner of the radar.
                .overlay(alignment: .bottomTrailing)
                {
                    PointingToggle(IsOn: Binding(get: { Selection.IsPointing }, set: { Selection.IsPointing = $0 }),
                                   Size: PhoneRadarView.ToggleSize)
                        .padding()
                        //Above the band under the radar where the selected place's name and distance appear.
                        .padding(.bottom, 40 * FittedScale)
                }
                .onGeometryChange(for: CGSize.self)
                {
                    $0.size
                }
                action:
                {
                    Available = $0
                }
                .gesture(MagnifyGesture()
                    .onChanged
                    {
                        Pinch in
                        if PinchStart == nil
                        {
                            PinchStart = Zoom
                        }
                        Zoom = PinchZoom.Zoom(Start: PinchStart ?? Zoom, Magnification: Pinch.magnification)
                    }
                    .onEnded
                    {
                        _ in
                        PinchStart = nil
                    })
            HStack
            {
                Image(systemName: "minus.magnifyingglass")
                Slider(value: $Zoom, in: 0.0 ... 1.0)
                Image(systemName: "plus.magnifyingglass")
            }
            .foregroundStyle(.white)
            .padding()
            .background(PhoneRadarView.Background)
        }
        //The clipped radar stops at the status bar, so the color behind it has to fill the screen.
        .background(PhoneRadarView.Background.ignoresSafeArea())
    }
}
