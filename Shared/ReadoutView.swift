//
//  ReadoutView.swift
//  HUDViewWatch Watch App
//
//  Created by Stuart Rankin on 10/26/26.
//

import SwiftUI

///Two lines at the bottom of the screen: the selected POI's name with its distance beneath it,
///or the heading/GPS status line when nothing is selected.
struct ReadoutView: View
{
    let Selected: POIFinder.VisiblePOI?
    ///Show the debug status line when nothing is selected.
    let ShowDebugStatus: Bool
    @ObservedObject var Compass: HeadingProvider
    ///True to left-align the text, for the upper-left corner of the watch; false to center it under the radar.
    var InCorner: Bool = false
    ///True on the iPhone, where there is room for much bigger text than on the watch.
    var Large: Bool = false
    ///Units for the selected place's distance.
    var Unit: DistanceUnit = .Metric
    ///True to show the current heading in whole degrees, in the same spot, when no place is selected (the watch).
    var ShowsHeading: Bool = false
    ///When given, shown while no place is selected: how many places are inside the radar's range (the iPhone).
    var PlaceCount: Int? = nil

    var body: some View
    {
        ZStack(alignment: InCorner ? .topLeading : .center)
        {
            //An empty view ignores a fixed frame height, so this keeps the space reserved when there is no text;
            //otherwise the radar would move down into it and jump up when text appears.
            Color.clear
            if let Item = Selected
            {
                VStack(alignment: InCorner ? .leading : .center, spacing: 0)
                {
                    Text(Item.Place.Name)
                        .font(Large ? .title2 : .caption)
                        .bold()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(DistanceFormat.Short(Meters: Item.Distance, Unit: Unit))
                        .font(Large ? .title3 : .caption2)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .modifier(AnnotationBox(Enabled: Large))
            }
            else if ShowDebugStatus
            {
                StatusLine(Compass: Compass)
            }
            else if let PlaceCount
            {
                Text("\(PlaceCount) \(PlaceCount == 1 ? "place" : "places") in range")
                    .font(Large ? .title3 : .caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            else if ShowsHeading
            {
                Text(HeadingFormat.Degrees(Compass.Heading))
                    .font(Large ? .title2 : .body)
                    .bold()
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
    }
}

///On the iPhone, puts the annotation on a translucent panel 80% as wide as the view. The container's width is the current one, so
///this follows the device's orientation.
struct AnnotationBox: ViewModifier
{
    let Enabled: Bool

    func body(content: Content) -> some View
    {
        if Enabled
        {
            content
                .padding(.vertical, 4)
                .containerRelativeFrame(.horizontal)
                {
                    Width, _ in
                    Width * 0.8
                }
                .background(.black.opacity(0.4), in: .rect(cornerRadius: 12))
        }
        else
        {
            content
        }
    }
}
