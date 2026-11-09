//
//  RadarSettings.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/5/26.
//

import Foundation
import Observation

///User settings for the radar. The iPhone is where they are changed; `WatchLink` sends them to the watch, which keeps its own copy.
@MainActor
@Observable
final class RadarSettings
{
    ///The range, in kilometers, of the radar's outer ring when fully zoomed out. Places farther away are not shown.
    nonisolated static let DefaultRangeKilometers = 800.0
    nonisolated static let RangeLimits = 25.0 ... 2000.0
    nonisolated static let RangeStep = 25.0

    ///The farthest distance, in kilometers, at which places are shown. Always within `RangeLimits`.
    var MaxRangeKilometers: Double
    {
        didSet
        {
            let Clamped = RadarSettings.Clamp(MaxRangeKilometers)
            if Clamped != MaxRangeKilometers
            {
                MaxRangeKilometers = Clamped
                return
            }
            Defaults.set(MaxRangeKilometers, forKey: RadarSettings.RangeKey)
        }
    }

    ///True to show only places inside the radar's outer ring. False draws places beyond the ring outside it, moving as the zoom changes.
    ///Used on the iPhone only.
    var CropToRange: Bool
    {
        didSet
        {
            Defaults.set(CropToRange, forKey: RadarSettings.CropKey)
        }
    }

    ///The units distances are shown in. Sent to the watch.
    var Unit: DistanceUnit
    {
        didSet
        {
            Defaults.set(Unit.rawValue, forKey: RadarSettings.UnitKey)
        }
    }

    ///The most places drawn at once on the camera view (iPhone only), nearest first.
    var HUDMarkerLimit: Int
    {
        didSet
        {
            let Clamped = RadarSettings.ClampMarkerLimit(HUDMarkerLimit)
            if Clamped != HUDMarkerLimit
            {
                HUDMarkerLimit = Clamped
                return
            }
            Defaults.set(HUDMarkerLimit, forKey: RadarSettings.MarkerLimitKey)
        }
    }

    ///True to hold the camera view's horizon level and put every place on it (iPhone only).
    var HorizonLocked: Bool
    {
        didSet
        {
            Defaults.set(HorizonLocked, forKey: RadarSettings.HorizonLockKey)
        }
    }

    ///True to show the Sun and the Moon on the camera view (iPhone only).
    var ShowSunMoon: Bool
    {
        didSet
        {
            Defaults.set(ShowSunMoon, forKey: RadarSettings.SunMoonKey)
        }
    }

    ///True to show the zodiac constellations on the camera view (iPhone only).
    var ShowZodiac: Bool
    {
        didSet
        {
            Defaults.set(ShowZodiac, forKey: RadarSettings.ZodiacKey)
        }
    }

    ///True to show Carina, Ophiuchus, Orion, the Big Dipper, the Little Dipper and the Southern Cross (iPhone only).
    var ShowOtherConstellations: Bool
    {
        didSet
        {
            Defaults.set(ShowOtherConstellations, forKey: RadarSettings.OtherConstellationsKey)
        }
    }

    ///True to show the Andromeda galaxy and the Magellanic Clouds on the camera view (iPhone only).
    var ShowGalaxies: Bool
    {
        didSet
        {
            Defaults.set(ShowGalaxies, forKey: RadarSettings.GalaxiesKey)
        }
    }

    ///The maximum range in meters.
    var MaxDistance: Double
    {
        MaxRangeKilometers * 1000
    }

    @ObservationIgnored
    private let Defaults: UserDefaults

    nonisolated static let RangeKey = "MaxRangeKilometers"
    nonisolated static let CropKey = "CropToRange"
    nonisolated static let UnitKey = "DistanceUnit"
    nonisolated static let MarkerLimitKey = "HUDMarkerLimit"
    nonisolated static let HorizonLockKey = "HorizonLocked"
    nonisolated static let SunMoonKey = "ShowSunMoon"
    nonisolated static let ZodiacKey = "ShowZodiac"
    nonisolated static let OtherConstellationsKey = "ShowOtherConstellations"
    nonisolated static let GalaxiesKey = "ShowGalaxies"
    nonisolated static let MarkerLimits = 3 ... 30
    nonisolated static let DefaultMarkerLimit = 10

    ///- Parameter Defaults: Where the setting is kept. Tests pass their own suite.
    init(Defaults: UserDefaults = .standard)
    {
        self.Defaults = Defaults
        let Saved = Defaults.object(forKey: RadarSettings.RangeKey) as? Double
        MaxRangeKilometers = RadarSettings.Clamp(Saved ?? RadarSettings.DefaultRangeKilometers)
        //Off by default: places beyond the outer ring are drawn outside it.
        CropToRange = Defaults.object(forKey: RadarSettings.CropKey) as? Bool ?? false
        Unit = (Defaults.string(forKey: RadarSettings.UnitKey)).flatMap { DistanceUnit(rawValue: $0) } ?? .Metric
        HUDMarkerLimit = RadarSettings.ClampMarkerLimit(Defaults.object(forKey: RadarSettings.MarkerLimitKey) as? Int ?? RadarSettings.DefaultMarkerLimit)
        HorizonLocked = Defaults.object(forKey: RadarSettings.HorizonLockKey) as? Bool ?? false
        ShowSunMoon = Defaults.object(forKey: RadarSettings.SunMoonKey) as? Bool ?? false
        ShowZodiac = Defaults.object(forKey: RadarSettings.ZodiacKey) as? Bool ?? false
        ShowOtherConstellations = Defaults.object(forKey: RadarSettings.OtherConstellationsKey) as? Bool ?? false
        ShowGalaxies = Defaults.object(forKey: RadarSettings.GalaxiesKey) as? Bool ?? false
    }

    ///Forces a range into `RangeLimits` and onto a multiple of `RangeStep`; a value that is not a number gives the default.
    nonisolated static func Clamp(_ Kilometers: Double) -> Double
    {
        guard Kilometers.isFinite else
        {
            return DefaultRangeKilometers
        }
        //Snapped to the step here rather than by the slider, because a stepped slider draws a row of tick marks under it.
        let Snapped = (Kilometers / RangeStep).rounded() * RangeStep
        return min(max(Snapped, RangeLimits.lowerBound), RangeLimits.upperBound)
    }

    ///Forces a marker limit into `MarkerLimits`.
    nonisolated static func ClampMarkerLimit(_ Limit: Int) -> Int
    {
        min(max(Limit, MarkerLimits.lowerBound), MarkerLimits.upperBound)
    }
}
