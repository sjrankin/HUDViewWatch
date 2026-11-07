//
//  RadarContent.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 10/26/26.
//  Moved out of the watch's ContentView so the iPhone app can show the same display.
//

import SwiftUI

///The radar with its two-line readout. The watch and the iPhone both show it; the watch zooms with the Digital Crown and the iPhone
///with a slider and a pinch, both through `Zoom`.
struct RadarContent: View
{
    ///Every place that may be plotted (the built-in ones and the user's own).
    let Places: [POI]
    @ObservedObject var Compass: HeadingProvider
    ///0 is fully zoomed out (MaxDistance), 1 is fully zoomed in. Zoom is logarithmic.
    @Binding var Zoom: Double
    ///Sizes everything (rings, markers, type) relative to the watch layout, which is 1.
    var Scale: Double = 1.0
    ///Points to move the whole radar down, to keep it clear of the watch's clock and battery indicator.
    var TopInset: Double = 0
    ///True to put the selected place's name and distance in the upper-left corner (the watch) instead of in a band under the radar
    ///(the iPhone). In the corner nothing is reserved below the radar, so the radar has the whole screen.
    var ReadoutInCorner: Bool = false
    ///True to show only places inside the outer ring. False shows every place within the maximum range, drawn outside the ring
    ///when it is beyond the current zoom's range.
    var CropToRange: Bool = true
    ///True to cut off markers at the edges of the radar's area (so they never reach the status bar, readout or slider).
    var ClipsToView: Bool = false
    ///True to draw a pulse at the center of the radar (the iPhone).
    var PulsesAtCenter: Bool = false
    ///True to show how many places are in range, below the radar, when none is selected (the iPhone).
    var ShowsCount: Bool = false
    ///The ids of the places the user created or edited. When markers crowd each other these are kept ahead of the built-in places.
    var UserPlaceIDs: Set<UUID> = []
    ///Units for distances shown on the radar.
    var Unit: DistanceUnit = .Metric
    ///Weight of the cardinal letters.
    var CardinalWeight: Font.Weight = .bold
    ///Points from the left edge to the corner readout; about the same gap as the clock has from the right edge.
    var CornerLeading: Double = 15
    ///Points from the top of the screen to the top of the corner readout; puts the top of the heading's digits level with the top of
    ///the watch's clock digits.
    var CornerTop: Double = 15.5

    let RingCount: Double = 4
    ///POIs farther than this many meters are not plotted; also the distance at the outer ring.
    ///The farthest distance in meters at which places are shown, and the outer ring when fully zoomed out. Set by the user on the iPhone.
    var MaxDistance: Double = 800_000
    ///Zoomed all the way in, the outer ring is MaxDistance times this (800 km * 0.0025 = 2 km).
    let MinRangeRatio: Double = 0.0025
    let RingLabelColor: Color = .white.opacity(0.7)
    ///Show the heading/GPS debug status line in the readout when no POI is selected.
    let ShowDebugStatus: Bool = false
    let StarColor: Color = .yellow
    ///Cardinal letters and their angles in degrees, clockwise from north.
    let Cardinals: [(Letter: String, Angle: Double)] = [("N", 0), ("E", 90), ("S", 180), ("W", 270)]
    ///Background color for the whole view.
    var BackgroundColor: Color = .indigo
    let RingColor: Color = .white
    var CardinalColor: Color = .black
    let CenterColor: Color = .black

    ///POIs within MaxDistance of the last location fix.
    @State private var NearbyPOIs: [POIFinder.VisiblePOI] = []
    ///The tapped POI, if any, when nothing outside the radar keeps the selection.
    @State private var LocalSelectedID: UUID? = nil
    ///A selection kept outside the radar (the iPhone shares it with the camera view); `nil` for the radar's own, as on the watch.
    var SharedSelection: Binding<UUID?>? = nil

    var SelectedID: UUID?
    {
        get
        {
            SharedSelection?.wrappedValue ?? LocalSelectedID
        }
        nonmutating set
        {
            if let SharedSelection
            {
                SharedSelection.wrappedValue = newValue
            }
            else
            {
                LocalSelectedID = newValue
            }
        }
    }

    var Gap: Double
    {
        40 * Scale
    }

    ///Diameter of each POI marker and of the location star.
    var IconSize: Double
    {
        14 * Scale
    }

    ///How close in points a tap must be to a marker to select it.
    var TapRadius: Double
    {
        20 * Scale
    }

    ///Height reserved at the bottom for the two-line readout; the radar sits in the space above it.
    var ReadoutHeight: Double
    {
        40 * Scale
    }

    ///Distance past the outer ring to the center of each cardinal letter.
    var NLabelOffset: Double
    {
        8 * Scale
    }

    ///Distance in meters at the outer ring for the current zoom.
    var RangeDistance: Double
    {
        return MaxDistance * pow(MinRangeRatio, Zoom)
    }

    ///Distance from the center to the center of each cardinal letter.
    var LabelRadius: Double
    {
        return ((Gap * RingCount) / 2) * 1.1 + NLabelOffset
    }

    ///POIs to draw: within the current range (when cropping), thinned out so markers do not overlap. The user's own places and the
    ///selected place win over the rest; see `RadarDeclutter`.
    var PlottedPOIs: [POIFinder.VisiblePOI]
    {
        let InRange = NearbyPOIs.filter
        {
            CropToRange == false || $0.Distance <= RangeDistance
        }
        return RadarDeclutter.Visible(InRange,
                                      UserPlaceIDs: UserPlaceIDs,
                                      SelectedID: SelectedID,
                                      RangeDistance: RangeDistance,
                                      PlotRadius: (Gap * RingCount) / 2,
                                      ClampsToRange: CropToRange,
                                      MinSpacing: RadarDeclutter.Spacing(IconSize: IconSize))
    }

    ///How many places are inside the outer ring (whether or not they are all drawn).
    var InRangeCount: Int
    {
        NearbyPOIs.filter { $0.Distance <= RangeDistance }.count
    }

    ///The selected POI if it is still being plotted, with its distance from the latest fix.
    var SelectedPOI: POIFinder.VisiblePOI?
    {
        return PlottedPOIs.first { $0.id == SelectedID }
    }

    func Refresh()
    {
        if let Here = Compass.Location
        {
            NearbyPOIs = POIFinder.POIs(In: Places, Near: Here, MaxDistance: MaxDistance)
        }
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            POIView(RingCount: RingCount,
                    Gap: Gap,
                    IconSize: IconSize,
                    POIs: PlottedPOIs,
                    RangeDistance: RangeDistance,
                    RingLabelColor: RingLabelColor,
                    SelectedID: SelectedID,
                    OnSelect: { SelectedID = $0?.id },
                    TapRadius: TapRadius,
                    StarColor: StarColor,
                    Heading: Compass.Heading,
                    LabelRadius: LabelRadius,
                    Cardinals: Cardinals,
                    BackgroundColor: BackgroundColor,
                    RingColor: RingColor,
                    CardinalColor: CardinalColor,
                    CenterColor: CenterColor,
                    Unit: Unit,
                    FontScale: Scale,
                    ClampsToRange: CropToRange,
                    PulsesAtCenter: PulsesAtCenter,
                    ClipsToView: ClipsToView,
                    CardinalWeight: CardinalWeight)
            //Offset rather than padding: the radar moves by the full amount and the readout below stays put.
            .offset(y: TopInset)
            //Room for two lines of text below the radar.
            if ReadoutInCorner == false
            {
                ReadoutView(Selected: SelectedPOI, ShowDebugStatus: ShowDebugStatus, Compass: Compass, Large: Scale > 1, Unit: Unit,
                            PlaceCount: ShowsCount ? InRangeCount : nil)
                    .frame(height: ReadoutHeight)
            }
        }
        .overlay(alignment: .topLeading)
        {
            if ReadoutInCorner
            {
                //Narrow enough to stay clear of the clock and battery indicator at the upper right.
                ReadoutView(Selected: SelectedPOI, ShowDebugStatus: ShowDebugStatus, Compass: Compass, InCorner: true, Unit: Unit, ShowsHeading: true)
                    .containerRelativeFrame(.horizontal) { Width, _ in Width * 0.55 }
                    .fixedSize(horizontal: false, vertical: true)
                    //A little in from the left edge, and down from the very top so the first line is level with the clock.
                    .padding(.leading, CornerLeading)
                    .padding(.top, CornerTop)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .background(BackgroundColor.ignoresSafeArea())
        .onAppear
        {
            Compass.Start()
            Refresh()
        }
        .onChange(of: Compass.Location)
        {
            Refresh()
        }
        .onChange(of: Places)
        {
            Refresh()
        }
        .onChange(of: MaxDistance)
        {
            Refresh()
        }
        .onDisappear
        {
            Compass.Stop()
        }
    }
}
