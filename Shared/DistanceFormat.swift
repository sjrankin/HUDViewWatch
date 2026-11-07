//
//  DistanceFormat.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 10/26/26.
//

import Foundation

///Formats distances for the range ring labels and readouts.
enum DistanceFormat
{
    ///Small units under a kilometer (or mile), one decimal of the large unit under 10, whole numbers beyond.
    static func Short(Meters: Double, Unit: DistanceUnit = .Metric) -> String
    {
        Unit.Format(Meters: Meters)
    }
}
