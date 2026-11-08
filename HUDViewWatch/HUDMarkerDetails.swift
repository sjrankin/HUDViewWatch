//
//  HUDMarkerDetails.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//

import SwiftUI

///The extra lines shown under the distance when a place is tapped on the camera view: what it is, which way it lies, how high it is
///and how many people live there. Lines the place has no data for are left out.
struct HUDMarkerDetails: View
{
    let Item: POIFinder.VisiblePOI
    let Unit: DistanceUnit

    var body: some View
    {
        VStack(spacing: 2)
        {
            if let Note = Item.Place.Description, Note.isEmpty == false
            {
                Text(Note)
                    .italic()
            }
            if let Sky = Item.SkyElevation
            {
                //Something in the sky: which way, and how high.
                Text("Direction \(HeadingFormat.Degrees(Item.Bearing)) \(HUDMath.DirectionName(Item.Bearing))")
                let Height = Int(abs(Sky).rounded())
                Text(Sky < 0.0 ? "\(Height)° below the horizon" : "\(Height)° above the horizon")
            }
            else
            {
                Text(Item.Place.Kind.rawValue)
                Text("Bearing \(HeadingFormat.Degrees(Item.Bearing)) \(HUDMath.DirectionName(Item.Bearing))")
                if let Height = Item.Place.Elevation
                {
                    Text("Elevation \(HUDMarkerDetails.Height(Meters: Height, Unit: Unit))")
                }
                if let Population = Item.Place.Population
                {
                    Text("Population \(Population, format: .number)")
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.black.opacity(0.8))
        .multilineTextAlignment(.center)
    }

    ///A height or altitude in whole meters or feet.
    static func Height(Meters: Double, Unit: DistanceUnit) -> String
    {
        let Length = Measurement(value: Meters, unit: UnitLength.meters)
        let Shown = Unit == .Metric ? Length : Length.converted(to: .feet)
        return Shown.formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                            numberFormatStyle: .number.precision(.fractionLength(0))))
    }
}
