//
//  DistanceUnit.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//  Adapted from POIDistanceUnit in HUDViewUI. The unit is a setting passed where it is needed rather than a global.
//

import Foundation

///The units distances are shown in.
enum DistanceUnit: String, CaseIterable, Codable, Identifiable
{
    case Metric
    case Imperial

    var id: String
    {
        rawValue
    }

    ///Words for the settings screen.
    var Title: String
    {
        switch self
        {
            case .Metric:
                return "Kilometers"

            case .Imperial:
                return "Miles"
        }
    }

    private static let MetersPerMile = 1609.344
    private static let FeetPerMeter = 3.28084

    ///A distance with small units under 1 km (or 1 mile), one decimal under 10 of the large unit, and whole numbers beyond.
    func Format(Meters: Double) -> String
    {
        let IsMetric = self == .Metric
        let Large = IsMetric ? Meters / 1000.0 : Meters / DistanceUnit.MetersPerMile
        if Large < 1.0
        {
            let Small = IsMetric ? Meters : Meters * DistanceUnit.FeetPerMeter
            return "\(Small.formatted(.number.precision(.fractionLength(0)))) \(IsMetric ? "m" : "ft")"
        }
        let Digits = Large < 10.0 ? 1 : 0
        return "\(Large.formatted(.number.precision(.fractionLength(Digits)))) \(IsMetric ? "km" : "mi")"
    }
}
