//
//  SkyTests.swift
//  HUDViewWatchTests
//
//  Created by Stuart Rankin on 11/8/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import HUDViewWatch

struct SkyTests
{
    private func Time(_ Text: String) -> Date
    {
        ISO8601DateFormatter().date(from: Text) ?? Date(timeIntervalSince1970: 0)
    }

    ///The angle in degrees between two directions given by right ascension and declination.
    private func Separation(_ A: SkyMath.Body, _ B: SkyMath.Body) -> Double
    {
        let D1 = A.Dec * .pi / 180
        let D2 = B.Dec * .pi / 180
        let DRA = (A.RA - B.RA) * .pi / 180
        let Cosine = sin(D1) * sin(D2) + cos(D1) * cos(D2) * cos(DRA)
        return acos(max(-1, min(1, Cosine))) * 180 / .pi
    }

    // MARK: The Sun

    @Test func TheSunIsOnTheEquatorAtTheEquinox()
    {
        //2026 March equinox: 14:46 UTC.
        #expect(abs(SkyMath.Sun(At: Time("2026-03-20T14:46:00Z")).Dec) < 0.2)
    }

    @Test func TheSunIsAtTheTropicAtTheSolstice()
    {
        //2026 June solstice: 08:24 UTC.
        #expect(abs(SkyMath.Sun(At: Time("2026-06-21T08:24:00Z")).Dec - 23.44) < 0.1)
    }

    @Test func TheSunIsNearerInJanuaryThanInJuly()
    {
        let January = SkyMath.Sun(At: Time("2026-01-03T12:00:00Z")).Distance / SkyMath.AstronomicalUnit
        let July = SkyMath.Sun(At: Time("2026-07-06T12:00:00Z")).Distance / SkyMath.AstronomicalUnit
        #expect(abs(January - 0.9833) < 0.002)
        #expect(abs(July - 1.0167) < 0.002)
    }

    @Test func TheSunIsOverheadAtNoonOnTheEquatorAtTheEquinox()
    {
        //Solar noon on the Greenwich meridian is a little after 12:00 UTC in March (the equation of time is about -7 minutes).
        let Sun = SkyMath.Sun(At: Time("2026-03-20T12:07:00Z"))
        let Place = SkyMath.Position(RA: Sun.RA, Dec: Sun.Dec, Latitude: 0, Longitude: 0, At: Time("2026-03-20T12:07:00Z"))
        #expect(Place.Altitude > 88.5)
    }

    // MARK: The Moon

    @Test func TheMoonIsBesideTheSunAtNewMoon()
    {
        //New moon: 2000 January 6, 18:14 UTC.
        let When = Time("2000-01-06T18:14:00Z")
        #expect(Separation(SkyMath.Sun(At: When), SkyMath.Moon(At: When)) < 6)
        #expect(SkyMath.MoonPhase(At: When).Lit < 0.03)
    }

    @Test func TheMoonIsOppositeTheSunAtFullMoon()
    {
        //Full moon: 2000 January 21, 04:40 UTC.
        let When = Time("2000-01-21T04:40:00Z")
        #expect(Separation(SkyMath.Sun(At: When), SkyMath.Moon(At: When)) > 170)
        #expect(SkyMath.MoonPhase(At: When).Lit > 0.97)
    }

    @Test func TheMoonIsWaxingAfterNewMoonAndWaningAfterFull()
    {
        #expect(SkyMath.MoonPhase(At: Time("2000-01-10T00:00:00Z")).IsWaxing)
        #expect(SkyMath.MoonPhase(At: Time("2000-01-25T00:00:00Z")).IsWaxing == false)
    }

    @Test func TheMoonIsAboutAQuarterOfAMillionMilesAway()
    {
        for Day in ["2026-01-01T00:00:00Z", "2026-03-15T00:00:00Z", "2026-07-04T00:00:00Z", "2026-10-20T00:00:00Z"]
        {
            let Distance = SkyMath.Moon(At: Time(Day)).Distance / 1000.0
            #expect(Distance > 356_000 && Distance < 407_000)
        }
    }

    // MARK: Where things are in the sky

    @Test func APointOnTheMeridianIsDueSouthAtTheRightHeight()
    {
        let When = Time("2026-11-08T06:00:00Z")
        let Longitude = -121.3
        //Its hour angle is zero when its right ascension is the local sidereal time.
        let RA = SkyMath.SiderealTime(At: When, Longitude: Longitude)
        let Place = SkyMath.Position(RA: RA, Dec: 20, Latitude: 38, Longitude: Longitude, At: When)
        #expect(abs(Place.Azimuth - 180) < 0.01)
        #expect(abs(Place.Altitude - (90 - (38 - 20))) < 0.01)
    }

    @Test func APointDueEastOfTheMeridianRisesInTheEast()
    {
        let When = Time("2026-11-08T06:00:00Z")
        let Longitude = 10.0
        //On the celestial equator, six hours (90°) of right ascension east of the meridian, seen from the equator: on the eastern horizon.
        let RA = SkyMath.SiderealTime(At: When, Longitude: Longitude) + 90
        let Place = SkyMath.Position(RA: SkyMath.Wrap(RA), Dec: 0, Latitude: 0, Longitude: Longitude, At: When)
        #expect(abs(Place.Altitude) < 0.01)
        #expect(abs(Place.Azimuth - 90) < 0.01)
    }

    // MARK: Places for the camera view

    @Test func ThePlacesFollowTheFlags()
    {
        let When = Time("2026-11-08T06:00:00Z")
        func Count(_ SunMoon: Bool, _ Zodiac: Bool, _ Others: Bool = false, _ Galaxies: Bool = false) -> Int
        {
            SkyObjects.Visible(At: When, Latitude: 38, Longitude: -121, ShowSunMoon: SunMoon, ShowZodiac: Zodiac,
                               ShowOthers: Others, ShowGalaxies: Galaxies).count
        }
        #expect(Count(false, false) == 0)
        #expect(Count(true, false) == 2)
        #expect(Count(false, true) == 12)
        #expect(Count(true, true) == 14)
        #expect(Count(false, false, true) == 6)
        #expect(Count(false, false, false, true) == 3)
        #expect(Count(true, true, true, true) == 23)
    }

    @Test func EverythingInTheSkyHasItsOwnDirectionAndAFixedID()
    {
        let When = Time("2026-11-08T06:00:00Z")
        let All = SkyObjects.Visible(At: When, Latitude: 38, Longitude: -121, ShowSunMoon: true, ShowZodiac: true,
                                     ShowOthers: true, ShowGalaxies: true)
        #expect(All.allSatisfy { $0.IsSky && $0.Place.Kind.IsCelestial })
        #expect(Set(All.map(\.id)).count == 23)
        #expect(Set(All.map(\.id)) == SkyObjects.AllIDs)
        //Again a minute later: the same ids.
        let Later = SkyObjects.Visible(At: When.addingTimeInterval(60), Latitude: 38, Longitude: -121, ShowSunMoon: true,
                                       ShowZodiac: true, ShowOthers: true, ShowGalaxies: true)
        #expect(Set(Later.map(\.id)) == SkyObjects.AllIDs)
    }

    @Test func TheSunAndMoonCarryTheirDistancesAndTheMoonItsPhase()
    {
        let When = Time("2026-11-08T06:00:00Z")
        let Found = SkyObjects.Visible(At: When, Latitude: 38, Longitude: -121, ShowSunMoon: true, ShowZodiac: false)
        let Sun = Found.first { $0.id == SkyObjects.SunID }
        let Moon = Found.first { $0.id == SkyObjects.MoonID }
        #expect(Sun.map { $0.Distance > 1.4e11 && $0.Distance < 1.6e11 } == true)
        #expect(Moon.map { $0.Distance > 3.5e8 && $0.Distance < 4.1e8 } == true)
        #expect(Moon?.Place.Description?.contains("lit") == true)
    }

    @Test func TheZodiacHasTwelveDistinctSignsInTheirOwnWords()
    {
        #expect(SkyObjects.Zodiac.count == 12)
        #expect(Set(SkyObjects.Zodiac.map(\.Name)).count == 12)
        #expect(SkyObjects.Zodiac.allSatisfy { (0.0 ..< 24.0).contains($0.RAHours) && (-90.0 ... 90.0).contains($0.Dec) })
    }

    @Test func TheOtherConstellationsAndGalaxiesAreAllThere()
    {
        let Names = Set(SkyObjects.Others.map(\.Name))
        #expect(Names == ["Carina", "Ophiuchus", "Orion", "Big Dipper", "Little Dipper", "Southern Cross"])
        #expect(Set(SkyObjects.Galaxies.map(\.Name)) == ["Andromeda Galaxy", "LMC", "SMC"])
        #expect(SkyObjects.Others.allSatisfy { (0.0 ..< 24.0).contains($0.RAHours) && (-90.0 ... 90.0).contains($0.Dec) })
        #expect(SkyObjects.Galaxies.allSatisfy { (0.0 ..< 24.0).contains($0.RAHours) && (-90.0 ... 90.0).contains($0.Dec) })
    }

    @Test func TheGalaxiesAreDrawnAtTheirRealDistances()
    {
        let When = Time("2026-11-08T06:00:00Z")
        let Found = SkyObjects.Visible(At: When, Latitude: 38, Longitude: -121, ShowSunMoon: false, ShowZodiac: false, ShowGalaxies: true)
        let Andromeda = Found.first { $0.Place.Name == "Andromeda Galaxy" }
        #expect(Andromeda.map { abs($0.Distance / DistanceUnit.MetersPerLightYear - 2_537_000) < 1 } == true)
        #expect(Found.allSatisfy { $0.Place.Kind == .Galaxy })
    }

    @Test func TheSouthernCrossIsBelowTheHorizonInTheNorthAndHighInTheSouth()
    {
        //Crux is at declination about -60°: it never rises north of latitude +30°, and it passes high overhead from the deep south.
        let When = Time("2026-11-08T06:00:00Z")
        var Best = -90.0
        var Worst = 90.0
        for Hour in 0 ..< 24
        {
            let Later = When.addingTimeInterval(Double(Hour) * 3600)
            let North = SkyMath.Position(RA: 12.45 * 15, Dec: -60, Latitude: 50, Longitude: 0, At: Later).Altitude
            let South = SkyMath.Position(RA: 12.45 * 15, Dec: -60, Latitude: -50, Longitude: 0, At: Later).Altitude
            Worst = min(Worst, North)
            Best = max(Best, South)
        }
        #expect(Worst < 0)
        #expect(Best > 70)
    }

    @Test func KindsOfTheSkyAreNotOfferedToTheUserForTheirOwnPlaces()
    {
        #expect(POIType.UserChoices.contains(.City))
        #expect(POIType.UserChoices.contains(where: \.IsCelestial) == false)
    }

    // MARK: On the camera view

    private func SkyItem(_ Name: String, Kind: POIType, Altitude: Double, Azimuth: Double) -> POIFinder.VisiblePOI
    {
        POIFinder.VisiblePOI(Place: POI(Name: Name, Latitude: 0, Longitude: 0, Kind: Kind), Distance: 1.5e11, Bearing: Azimuth,
                             SkyElevation: Altitude)
    }

    private func Ground(_ Name: String, Distance: Double) -> POIFinder.VisiblePOI
    {
        POIFinder.VisiblePOI(Place: POI(Name: Name, Latitude: 0, Longitude: 0, Kind: .Test), Distance: Distance, Bearing: 0)
    }

    @Test func TheSkyIsPlacedByItsOwnAltitudeNotByDistance()
    {
        //Level, facing north, camera level, locked off: the Sun 30° above the horizon, due north, is above the middle of the view.
        let Sun = SkyItem("Sun", Kind: .Sun, Altitude: 30, Azimuth: 0)
        let Frame = HUDMath.MakeFrame(Items: [Sun], DeviceHeading: 0, Pull: .Upright, Size: CGSize(width: 400, height: 800),
                                      Orientation: .portrait, FieldOfView: 63, IsFrontCamera: false, Locked: false,
                                      UserHeight: 0, Limit: 20)
        let Point = Frame.Placements.first?.Point
        #expect(Point != nil)
        #expect(Point.map { Double($0.y) < 400 } == true)
        //A place on the ground 50 km away at your height is just below the horizon, so lower on the view than the Sun.
        let Same = HUDMath.MakeFrame(Items: [Ground("Far", Distance: 50_000)], DeviceHeading: 0, Pull: .Upright,
                                     Size: CGSize(width: 400, height: 800), Orientation: .portrait, FieldOfView: 63,
                                     IsFrontCamera: false, Locked: false, UserHeight: 0, Limit: 20)
        #expect(Same.Placements.first.map { $0.Point.y > (Point?.y ?? 0) } == true)
    }

    @Test func TheLimitCountsPlacesOnTheGroundButNeverDropsTheSky()
    {
        let Items = [Ground("A", Distance: 1000), Ground("B", Distance: 2000), Ground("C", Distance: 3000),
                     SkyItem("Sun", Kind: .Sun, Altitude: 0, Azimuth: 0)]
        let Frame = HUDMath.MakeFrame(Items: Items, DeviceHeading: 0, Pull: .Upright, Size: CGSize(width: 400, height: 800),
                                      Orientation: .portrait, FieldOfView: 63, IsFrontCamera: false, Locked: false,
                                      UserHeight: 0, Limit: 1)
        let Names = Frame.Placements.map(\.Item.Place.Name)
        #expect(Names.contains("A"))
        #expect(Names.contains("Sun"))
        #expect(Names.contains("B") == false)
    }

    @Test func ABodyBelowTheHorizonIsPlacedBelowTheLevel()
    {
        //Facing north, camera level: a body 20° below the horizon is below the middle of the view; the middle is the horizon here.
        let Low = SkyItem("Moon", Kind: .Moon, Altitude: -20, Azimuth: 0)
        let Frame = HUDMath.MakeFrame(Items: [Low], DeviceHeading: 0, Pull: .Upright, Size: CGSize(width: 400, height: 800),
                                      Orientation: .portrait, FieldOfView: 63, IsFrontCamera: false, Locked: false,
                                      UserHeight: 0, Limit: 20)
        #expect(Frame.Placements.first.map { $0.Point.y > 400 } == true)
    }

    // MARK: Words

    @Test func AstronomicalDistancesAreInMillionsOfKilometers()
    {
        #expect(DistanceUnit.Metric.Format(Meters: 149_597_870_700) == "149.6 million km")
        #expect(DistanceUnit.Imperial.Format(Meters: 149_597_870_700) == "93.0 million mi")
        //Nothing changes for ordinary distances.
        #expect(DistanceUnit.Metric.Format(Meters: 384_400_000) == "384,400 km")
        //Galaxies: light-years, whichever units are in use.
        #expect(DistanceUnit.Metric.Format(Meters: 2_537_000 * DistanceUnit.MetersPerLightYear) == "2.5 million light-years")
        #expect(DistanceUnit.Imperial.Format(Meters: 160_000 * DistanceUnit.MetersPerLightYear) == "160,000 light-years")
    }
}

@MainActor
struct SkySettingsTests
{
    @Test func TheSkyFlagsAreOffByDefaultAndRemembered()
    {
        let Name = "SkySettingsTests-\(UUID().uuidString)"
        guard let Suite = UserDefaults(suiteName: Name) else
        {
            Issue.record("No test defaults")
            return
        }
        defer { Suite.removePersistentDomain(forName: Name) }
        let First = RadarSettings(Defaults: Suite)
        #expect(First.ShowSunMoon == false)
        #expect(First.ShowZodiac == false)
        #expect(First.ShowOtherConstellations == false)
        #expect(First.ShowGalaxies == false)
        First.ShowSunMoon = true
        First.ShowZodiac = true
        First.ShowOtherConstellations = true
        First.ShowGalaxies = true
        let Second = RadarSettings(Defaults: Suite)
        #expect(Second.ShowSunMoon)
        #expect(Second.ShowZodiac)
        #expect(Second.ShowOtherConstellations)
        #expect(Second.ShowGalaxies)
    }
}
