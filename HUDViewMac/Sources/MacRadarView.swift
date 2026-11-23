//
//  MacRadarView.swift
//  HUDViewMac
//
//  Created by Stuart Rankin on 11/22/26.
//

import SwiftUI

///The radar, drawn from the iPhone's frames, with a side panel of the raw data.
struct MacRadarView: View
{
    @Environment(OrientationReceiver.self) private var Receiver
    @Environment(POIStore.self) private var Store
    @Environment(RadarSettings.self) private var Settings
    @Environment(PlaceSelection.self) private var Selection
    ///0 is fully zoomed out, 1 fully zoomed in.
    @State private var Zoom: Double = 0.2314
    ///The zoom when the current pinch began; `nil` between pinches.
    @State private var PinchStart: Double? = nil
    ///The space the radar has to fill.
    @State private var Available = CGSize.zero

    private static let Background = Color.indigo.mix(with: .black, by: 0.2)
    ///The same radar proportions as `PhoneRadarView`.
    private static let ExtentPerScale = 204.0
    private static let HeightPerScale = 208.0
    ///The width and height of the pointer toggle, in points.
    private static let ToggleSize = 64.0
    ///The scale of the place icons, which stay one size whatever the window's size (1 is the watch's icon, 14 points). A later setting
    ///for accessibility can change this.
    private static let IconScale = 1.5

    ///The scale that makes the radar fill the space it is given.
    var FittedScale: Double
    {
        guard Available.width > 0, Available.height > 0 else
        {
            return 1.7
        }
        return min(Available.width / MacRadarView.ExtentPerScale, Available.height / MacRadarView.HeightPerScale) * 0.98
    }

    var body: some View
    {
        @Bindable var Bound = Settings
        HStack(spacing: 0)
        {
            VStack(spacing: 0)
            {
                ZStack(alignment: .bottomTrailing)
                {
                    RadarContent(Places: Store.Visible, Compass: Receiver.Compass, Zoom: $Zoom, Scale: FittedScale,
                                 ReadoutReservesSpace: false, CropToRange: Settings.CropToRange, ClipsToView: true,
                                 IsPointing: Selection.IsPointing, IconScale: MacRadarView.IconScale, ArrowScale: 1.8, ArrowWidthScale: 0.85, UserPlaceIDs: Set(Store.Custom.map(\.id)),
                                 ShowsMap: Settings.ShowMap, Unit: Settings.Unit, CardinalWeight: .heavy,
                                 MaxDistance: Settings.MaxDistance, BackgroundColor: MacRadarView.Background,
                                 CardinalColor: Color(red: 1, green: 1, blue: 0),
                                 SharedSelection: Binding(get: { Selection.SelectedID }, set: { Selection.SelectedID = $0 }))
                        .onGeometryChange(for: CGSize.self)
                        {
                            $0.size
                        }
                        action:
                        {
                            Available = $0
                        }
                        //The mouse wheel or a two-finger scroll zooms, and a trackpad pinch, as on the iPhone.
                        .background
                        {
                            ScrollZoom
                            {
                                Amount in
                                Zoom = min(max(Zoom + Amount, 0.0), 1.0)
                            }
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
                    //The same toggle as on the iPhone, in the lower-right corner of the radar.
                    PointingToggle(IsOn: Binding(get: { Selection.IsPointing }, set: { Selection.IsPointing = $0 }), Size: MacRadarView.ToggleSize, LargeGlyph: true)
                        .padding()
                        //Above the band under the radar where the selected place's name and distance appear.
                        .padding(.bottom, 40 * FittedScale)
                    //Updates once a second so the message appears when the phone goes quiet, without any network call.
                    TimelineView(.periodic(from: .now, by: 1))
                    {
                        Context in
                        ConnectionBanner(Status: Receiver.Status, Age: Receiver.Age(At: Context.date), HasLocation: Receiver.Compass.Location != nil)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                }
                HStack
                {
                    Image(systemName: "minus.magnifyingglass")
                    Slider(value: $Zoom, in: 0.0 ... 1.0)
                    Image(systemName: "plus.magnifyingglass")
                }
                .foregroundStyle(.white)
                .padding()
                .background(MacRadarView.Background)
            }
            Divider()
            TimelineView(.periodic(from: .now, by: 1))
            {
                Context in
                DataPanel(Frame: Receiver.Latest, Age: Receiver.Age(At: Context.date))
            }
            .frame(width: 250)
        }
        .toolbar
        {
            ToolbarItem
            {
                Toggle("Map", systemImage: "map", isOn: $Bound.ShowMap)
            }
            ToolbarItem
            {
                Picker("Units", selection: $Bound.Unit)
                {
                    ForEach(DistanceUnit.allCases)
                    {
                        Unit in
                        Text(Unit.Title)
                            .tag(Unit)
                    }
                }
            }
        }
    }
}
