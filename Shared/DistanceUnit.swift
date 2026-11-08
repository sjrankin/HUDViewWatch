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

    ///Meters in a light-year.
    static let MetersPerLightYear = 9_460_730_472_580_800.0
    private static let MetersPerMile = 1609.344
    private static let FeetPerMeter = 3.28084

    ///A distance with small units under 1 km (or 1 mile), one decimal under 10 of the large unit, and whole numbers beyond.
    func Format(Meters: Double) -> String
    {
        //Beyond the Solar System: light-years, whichever units are in use.
        let LightYears = Meters / DistanceUnit.MetersPerLightYear
        if LightYears >= 1_000_000.0
        {
            return "\((LightYears / 1_000_000.0).formatted(.number.precision(.fractionLength(1)))) million light-years"
        }
        if LightYears >= 1.0
        {
            return "\(LightYears.formatted(.number.precision(.fractionLength(0)))) light-years"
        }
        let IsMetric = self == .Metric
        let Large = IsMetric ? Meters / 1000.0 : Meters / DistanceUnit.MetersPerMile
        if Large < 1.0
        {
            let Small = IsMetric ? Meters : Meters * DistanceUnit.FeetPerMeter
            return "\(Small.formatted(.number.precision(.fractionLength(0)))) \(IsMetric ? "m" : "ft")"
        }
        //Astronomical distances: millions of kilometers (or miles).
        if Large >= 1_000_000.0
        {
            return "\((Large / 1_000_000.0).formatted(.number.precision(.fractionLength(1)))) million \(IsMetric ? "km" : "mi")"
        }
        let Digits = Large < 10.0 ? 1 : 0
        return "\(Large.formatted(.number.precision(.fractionLength(Digits)))) \(IsMetric ? "km" : "mi")"
    }
}
