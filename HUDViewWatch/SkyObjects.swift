//
//  SkyObjects.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/8/26.
//

import Foundation

///The Sun, the Moon and the zodiac constellations as places for the camera view. Each is a `VisiblePOI` whose direction comes from the
///sky (its altitude and azimuth) rather than from a spot on the map, so it is drawn, tapped and pointed at like any other place.
enum SkyObjects
{
    ///A zodiac constellation: where its middle is on the celestial sphere (J2000).
    struct Constellation
    {
        let Name: String
        ///What it is called in English, with its sign.
        let Meaning: String
        ///Right ascension of the middle, in hours.
        let RAHours: Double
        ///Declination of the middle, in degrees.
        let Dec: Double
    }

    ///The twelve zodiac constellations, with the middle of each (approximate: the constellations are large and irregular).
    static let Zodiac: [Constellation] =
    [
        Constellation(Name: "Aries", Meaning: "♈\u{FE0E} The Ram", RAHours: 2.63, Dec: 20.8),
        Constellation(Name: "Taurus", Meaning: "♉\u{FE0E} The Bull", RAHours: 4.70, Dec: 14.9),
        Constellation(Name: "Gemini", Meaning: "♊\u{FE0E} The Twins", RAHours: 7.08, Dec: 22.5),
        Constellation(Name: "Cancer", Meaning: "♋\u{FE0E} The Crab", RAHours: 8.63, Dec: 19.8),
        Constellation(Name: "Leo", Meaning: "♌\u{FE0E} The Lion", RAHours: 10.67, Dec: 13.1),
        Constellation(Name: "Virgo", Meaning: "♍\u{FE0E} The Maiden", RAHours: 13.33, Dec: -4.0),
        Constellation(Name: "Libra", Meaning: "♎\u{FE0E} The Scales", RAHours: 15.18, Dec: -15.1),
        Constellation(Name: "Scorpius", Meaning: "♏\u{FE0E} The Scorpion", RAHours: 16.90, Dec: -27.0),
        Constellation(Name: "Sagittarius", Meaning: "♐\u{FE0E} The Archer", RAHours: 19.00, Dec: -29.0),
        Constellation(Name: "Capricornus", Meaning: "♑\u{FE0E} The Sea-Goat", RAHours: 21.00, Dec: -18.0),
        Constellation(Name: "Aquarius", Meaning: "♒\u{FE0E} The Water Bearer", RAHours: 22.33, Dec: -10.0),
        Constellation(Name: "Pisces", Meaning: "♓\u{FE0E} The Fish", RAHours: 0.50, Dec: 10.0),
    ]

    ///The constellations and star patterns beyond the zodiac. (The Big and Little Dippers are patterns within Ursa Major and Ursa Minor.)
    static let Others: [Constellation] =
    [
        Constellation(Name: "Carina", Meaning: "The Keel", RAHours: 8.70, Dec: -63.0),
        Constellation(Name: "Ophiuchus", Meaning: "⛎\u{FE0E} The Serpent Bearer", RAHours: 17.40, Dec: -8.0),
        Constellation(Name: "Orion", Meaning: "The Hunter", RAHours: 5.60, Dec: -1.2),
        Constellation(Name: "Big Dipper", Meaning: "In Ursa Major, the Great Bear", RAHours: 12.26, Dec: 57.0),
        Constellation(Name: "Little Dipper", Meaning: "In Ursa Minor, the Little Bear", RAHours: 15.00, Dec: 75.0),
        Constellation(Name: "Southern Cross", Meaning: "Crux", RAHours: 12.45, Dec: -60.0),
    ]

    ///A galaxy: where it is and how far away.
    struct Galaxy
    {
        let Name: String
        let Note: String
        let RAHours: Double
        let Dec: Double
        ///Distance in light-years.
        let LightYears: Double
    }

    ///The Andromeda galaxy and the two Magellanic Clouds.
    static let Galaxies: [Galaxy] =
    [
        Galaxy(Name: "Andromeda Galaxy", Note: "M31, the nearest large galaxy", RAHours: 0.712, Dec: 41.27, LightYears: 2_537_000),
        Galaxy(Name: "LMC", Note: "Large Magellanic Cloud", RAHours: 5.393, Dec: -69.75, LightYears: 160_000),
        Galaxy(Name: "SMC", Note: "Small Magellanic Cloud", RAHours: 0.879, Dec: -72.82, LightYears: 200_000),
    ]

    ///How far the constellations are drawn as being, in meters: so far that they sort behind everything else.
    static let ConstellationDistance = 1.0e18

    ///The ids of the Sun, the Moon and the constellations. They are fixed so that a selected one stays selected as it moves.
    private static func ID(_ Number: Int) -> UUID
    {
        UUID(uuidString: "5C0A0000-0000-4000-8000-0000000000" + (Number < 10 ? "0\(Number)" : "\(Number)")) ?? UUID()
    }

    static let SunID = ID(1)
    static let MoonID = ID(2)
    static let ConstellationIDs: [UUID] = Zodiac.indices.map { ID(10 + $0) }
    static let OtherConstellationIDs: [UUID] = Others.indices.map { ID(30 + $0) }
    static let GalaxyIDs: [UUID] = Galaxies.indices.map { ID(40 + $0) }
    ///Every id this file makes.
    static let AllIDs: Set<UUID> = Set([SunID, MoonID] + ConstellationIDs + OtherConstellationIDs + GalaxyIDs)

    ///The sky objects to show now, as places.
    ///- Parameter Latitude: The observer's latitude in degrees.
    ///- Parameter Longitude: The observer's longitude in degrees, east positive.
    ///- Parameter ShowSunMoon: True to include the Sun and the Moon.
    ///- Parameter ShowZodiac: True to include the zodiac constellations.
    ///- Parameter ShowOthers: True to include the other constellations (Orion, the Southern Cross and so on).
    ///- Parameter ShowGalaxies: True to include the galaxies.
    static func Visible(At Time: Date, Latitude: Double, Longitude: Double, ShowSunMoon: Bool, ShowZodiac: Bool,
                        ShowOthers: Bool = false, ShowGalaxies: Bool = false) -> [POIFinder.VisiblePOI]
    {
        var Found: [POIFinder.VisiblePOI] = []
        if ShowSunMoon
        {
            let Sun = SkyMath.Sun(At: Time)
            let Where = SkyMath.Position(RA: Sun.RA, Dec: Sun.Dec, Latitude: Latitude, Longitude: Longitude, At: Time)
            Found.append(Make(ID: SunID, Name: "Sun", Kind: .Sun, Note: "The Sun", Distance: Sun.Distance, Direction: Where))
            let Moon = SkyMath.MoonPosition(Latitude: Latitude, Longitude: Longitude, At: Time)
            let Phase = SkyMath.MoonPhase(At: Time)
            let Lit = Int((Phase.Lit * 100.0).rounded())
            Found.append(Make(ID: MoonID, Name: "Moon", Kind: .Moon, Note: "\(Lit)% lit, \(Phase.IsWaxing ? "waxing" : "waning")",
                              Distance: Moon.Distance, Direction: Moon.Position))
        }
        if ShowZodiac
        {
            for (Index, Sign) in Zodiac.enumerated()
            {
                let Where = SkyMath.Position(RA: Sign.RAHours * 15.0, Dec: Sign.Dec, Latitude: Latitude, Longitude: Longitude, At: Time)
                Found.append(Make(ID: ConstellationIDs[Index], Name: Sign.Name, Kind: .Constellation, Note: Sign.Meaning,
                                  Distance: ConstellationDistance, Direction: Where))
            }
        }
        if ShowOthers
        {
            for (Index, Pattern) in Others.enumerated()
            {
                let Where = SkyMath.Position(RA: Pattern.RAHours * 15.0, Dec: Pattern.Dec, Latitude: Latitude, Longitude: Longitude, At: Time)
                Found.append(Make(ID: OtherConstellationIDs[Index], Name: Pattern.Name, Kind: .Constellation, Note: Pattern.Meaning,
                                  Distance: ConstellationDistance, Direction: Where))
            }
        }
        if ShowGalaxies
        {
            for (Index, Item) in Galaxies.enumerated()
            {
                let Where = SkyMath.Position(RA: Item.RAHours * 15.0, Dec: Item.Dec, Latitude: Latitude, Longitude: Longitude, At: Time)
                Found.append(Make(ID: GalaxyIDs[Index], Name: Item.Name, Kind: .Galaxy, Note: Item.Note,
                                  Distance: Item.LightYears * DistanceUnit.MetersPerLightYear, Direction: Where))
            }
        }
        return Found
    }

    private static func Make(ID: UUID, Name: String, Kind: POIType, Note: String, Distance: Double,
                             Direction: SkyMath.Horizontal) -> POIFinder.VisiblePOI
    {
        POIFinder.VisiblePOI(Place: POI(ID: ID, Name: Name, Latitude: 0.0, Longitude: 0.0, Kind: Kind, Description: Note),
                             Distance: Distance, Bearing: Direction.Azimuth, SkyElevation: Direction.Altitude)
    }
}
