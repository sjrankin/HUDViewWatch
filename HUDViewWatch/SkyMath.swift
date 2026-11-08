//
//  SkyMath.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/8/26.
//

import Foundation

///Where the Sun, the Moon and a point on the celestial sphere are in the sky, from the date and the observer's place. The formulas are the
///low-precision ones of the Astronomical Almanac and of Meeus: good to about a hundredth of a degree for the Sun and a third of a degree
///for the Moon, which is far better than a hand-held phone can aim.
enum SkyMath
{
    ///Meters in an astronomical unit.
    static let AstronomicalUnit = 149_597_870_700.0

    ///The position of a body: its place on the celestial sphere and how far away it is.
    struct Body: Equatable
    {
        ///Right ascension in degrees, 0 ..< 360.
        var RA: Double
        ///Declination in degrees, -90 ... 90.
        var Dec: Double
        ///Meters from the center of the Earth.
        var Distance: Double
        ///Longitude along the ecliptic in degrees, 0 ..< 360 (for the phase of the Moon).
        var EclipticLongitude: Double
        ///The Moon's horizontal parallax in degrees (0 for the Sun, whose parallax is too small to matter).
        var Parallax: Double = 0.0
    }

    ///Where a point is as seen from the ground.
    struct Horizontal: Equatable
    {
        ///Degrees above the horizon (negative below it).
        var Altitude: Double
        ///Degrees clockwise from true north, 0 ..< 360.
        var Azimuth: Double
    }

    private static func Radians(_ Degrees: Double) -> Double
    {
        Degrees * .pi / 180.0
    }

    private static func Degrees(_ Radians: Double) -> Double
    {
        Radians * 180.0 / .pi
    }

    ///An angle brought into 0 ..< 360.
    static func Wrap(_ Angle: Double) -> Double
    {
        let Remainder = Angle.truncatingRemainder(dividingBy: 360.0)
        return Remainder < 0.0 ? Remainder + 360.0 : Remainder
    }

    ///Days since the epoch J2000.0 (2000 January 1, 12:00 UT).
    static func DaysSinceJ2000(_ Time: Date) -> Double
    {
        Time.timeIntervalSince1970 / 86_400.0 + 2_440_587.5 - 2_451_545.0
    }

    ///The Sun.
    static func Sun(At Time: Date) -> Body
    {
        let Days = DaysSinceJ2000(Time)
        let MeanLongitude = Wrap(280.460 + 0.9856474 * Days)
        let Anomaly = Radians(Wrap(357.528 + 0.9856003 * Days))
        let Longitude = Radians(Wrap(MeanLongitude + 1.915 * sin(Anomaly) + 0.020 * sin(2.0 * Anomaly)))
        let Obliquity = Radians(23.439 - 0.0000004 * Days)
        let AU = 1.00014 - 0.01671 * cos(Anomaly) - 0.00014 * cos(2.0 * Anomaly)
        let RA = atan2(cos(Obliquity) * sin(Longitude), cos(Longitude))
        let Dec = asin(sin(Obliquity) * sin(Longitude))
        return Body(RA: Wrap(Degrees(RA)), Dec: Degrees(Dec), Distance: AU * AstronomicalUnit, EclipticLongitude: Degrees(Longitude))
    }

    ///The Moon.
    static func Moon(At Time: Date) -> Body
    {
        let Centuries = DaysSinceJ2000(Time) / 36_525.0
        func Sine(_ Start: Double, _ Rate: Double) -> Double
        {
            sin(Radians(Start + Rate * Centuries))
        }
        func Cosine(_ Start: Double, _ Rate: Double) -> Double
        {
            cos(Radians(Start + Rate * Centuries))
        }
        let Longitude = 218.32 + 481_267.881 * Centuries
            + 6.29 * Sine(135.0, 477_198.87) - 1.27 * Sine(259.3, -413_335.36) + 0.66 * Sine(235.7, 890_534.22)
            + 0.21 * Sine(269.9, 954_397.74) - 0.19 * Sine(357.5, 35_999.05) - 0.11 * Sine(186.5, 966_404.03)
        let Latitude = 5.13 * Sine(93.3, 483_202.02) + 0.28 * Sine(228.2, 960_400.89) - 0.28 * Sine(318.3, 6_003.15)
            - 0.17 * Sine(217.6, -407_332.21)
        let Parallax = 0.9508 + 0.0518 * Cosine(135.0, 477_198.87) + 0.0095 * Cosine(259.3, -413_335.36)
            + 0.0078 * Cosine(235.7, 890_534.22) + 0.0028 * Cosine(269.9, 954_397.74)
        //Earth radii to the Moon, then meters.
        let Distance = 6_378_140.0 / sin(Radians(Parallax))
        let L = Radians(Longitude)
        let B = Radians(Latitude)
        let X = cos(B) * cos(L)
        let Y = 0.9175 * cos(B) * sin(L) - 0.3978 * sin(B)
        let Z = 0.3978 * cos(B) * sin(L) + 0.9175 * sin(B)
        return Body(RA: Wrap(Degrees(atan2(Y, X))), Dec: Degrees(asin(Z)), Distance: Distance,
                    EclipticLongitude: Wrap(Longitude), Parallax: Parallax)
    }

    ///The local sidereal time in degrees at the given longitude (east positive).
    static func SiderealTime(At Time: Date, Longitude: Double) -> Double
    {
        Wrap(280.46061837 + 360.98564736629 * DaysSinceJ2000(Time) + Longitude)
    }

    ///Where a point on the celestial sphere is in the sky of an observer.
    ///- Parameter RA: Right ascension in degrees.
    ///- Parameter Dec: Declination in degrees.
    ///- Parameter Latitude: The observer's latitude in degrees.
    ///- Parameter Longitude: The observer's longitude in degrees, east positive.
    static func Position(RA: Double, Dec: Double, Latitude: Double, Longitude: Double, At Time: Date) -> Horizontal
    {
        let HourAngle = Radians(SiderealTime(At: Time, Longitude: Longitude) - RA)
        let Phi = Radians(Latitude)
        let Delta = Radians(Dec)
        let SinAltitude = sin(Phi) * sin(Delta) + cos(Phi) * cos(Delta) * cos(HourAngle)
        let Altitude = asin(max(-1.0, min(1.0, SinAltitude)))
        let Azimuth = atan2(-cos(Delta) * sin(HourAngle), sin(Delta) * cos(Phi) - cos(Delta) * sin(Phi) * cos(HourAngle))
        return Horizontal(Altitude: Degrees(Altitude), Azimuth: Wrap(Degrees(Azimuth)))
    }

    ///The Moon as seen from the ground rather than from the Earth's center: it is low enough for the shift (up to about a degree)
    ///to matter.
    static func MoonPosition(Latitude: Double, Longitude: Double, At Time: Date) -> (Position: Horizontal, Distance: Double)
    {
        let Moon = Moon(At: Time)
        var Place = Position(RA: Moon.RA, Dec: Moon.Dec, Latitude: Latitude, Longitude: Longitude, At: Time)
        Place.Altitude -= Moon.Parallax * cos(Radians(Place.Altitude))
        return (Place, Moon.Distance)
    }

    ///How much of the Moon's face is lit (0 ... 1) and whether it is growing, from how far the Moon is ahead of the Sun along the sky.
    static func MoonPhase(At Time: Date) -> (Lit: Double, IsWaxing: Bool)
    {
        let Ahead = Wrap(Moon(At: Time).EclipticLongitude - Sun(At: Time).EclipticLongitude)
        return ((1.0 - cos(Radians(Ahead))) / 2.0, Ahead < 180.0)
    }
}
