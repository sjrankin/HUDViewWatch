//
//  LocationToast.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//  Ported from Toast in HUDViewUI.
//

import SwiftUI
import CoreLocation

///A card over the camera with the current heading, position and altitude. Tap it to close it.
struct LocationToast: View
{
    ///Degrees from north the top of the phone points, or `nil` when there is no heading.
    let Heading: Double?
    let Location: CLLocation?
    let Unit: DistanceUnit
    let OnClose: () -> Void

    var body: some View
    {
        Button(action: OnClose)
        {
            VStack(spacing: 4)
            {
                if let Heading
                {
                    Text("\(HUDMath.DirectionName(Heading)) \(HeadingFormat.Degrees(Heading))")
                        .font(.title3.bold())
                }
                else
                {
                    Text("Heading unavailable")
                        .font(.title3.bold())
                }
                if let Location
                {
                    Text("\(Location.coordinate.latitude.formatted(.number.precision(.fractionLength(5))))°, \(Location.coordinate.longitude.formatted(.number.precision(.fractionLength(5))))°")
                    Text("Altitude \(DistanceFormat.Short(Meters: Location.altitude, Unit: Unit))  ±\(DistanceFormat.Short(Meters: Location.horizontalAccuracy, Unit: Unit))")
                }
                else
                {
                    Text("No location")
                }
            }
            .font(.title3)
            .foregroundStyle(.white)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.black.opacity(0.75), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Closes this card")
    }
}
