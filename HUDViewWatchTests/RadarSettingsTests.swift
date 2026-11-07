//
//  RadarSettingsTests.swift
//  HUDViewWatchTests
//
//  Created by Stuart Rankin on 11/5/26.
//

import Foundation
import Testing
@testable import HUDViewWatch

@MainActor
struct RadarSettingsTests
{
    ///Settings that keep their value in a private suite.
    func MakeSettings() -> (RadarSettings, UserDefaults, String)
    {
        let Name = "HUDViewWatchTests-\(UUID().uuidString)"
        let Defaults = UserDefaults(suiteName: Name)!
        return (RadarSettings(Defaults: Defaults), Defaults, Name)
    }

    @Test func StartsAtTheDefaultRange()
    {
        let (Settings, _, _) = MakeSettings()
        #expect(Settings.MaxRangeKilometers == 800)
        #expect(Settings.MaxDistance == 800_000)
    }

    @Test func RangeIsKeptWithinLimits()
    {
        let (Settings, _, _) = MakeSettings()
        Settings.MaxRangeKilometers = 5
        #expect(Settings.MaxRangeKilometers == RadarSettings.RangeLimits.lowerBound)
        Settings.MaxRangeKilometers = 99_999
        #expect(Settings.MaxRangeKilometers == RadarSettings.RangeLimits.upperBound)
        #expect(RadarSettings.Clamp(.nan) == RadarSettings.DefaultRangeKilometers)
    }

    @Test func RangeIsRememberedBetweenLaunches()
    {
        let (Settings, Defaults, _) = MakeSettings()
        Settings.MaxRangeKilometers = 300
        let Again = RadarSettings(Defaults: Defaults)
        #expect(Again.MaxRangeKilometers == 300)
    }

    @Test func CroppingIsOffByDefaultAndIsRemembered()
    {
        let (Settings, Defaults, _) = MakeSettings()
        #expect(Settings.CropToRange == false)
        Settings.CropToRange = true
        #expect(RadarSettings(Defaults: Defaults).CropToRange)
    }
}
