//
//  RadarGuide.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/8/26.
//

import Foundation
import CoreGraphics

///The geometry of the radar's pointing mode: an arrow from the center of the radar to the chosen place, and the bearing shown behind it.
enum RadarGuide
{
    ///The direction of a place on the screen: degrees clockwise from the top of the screen, 0 up to (but not including) 360. The top of
    ///the radar is the way the watch faces, so this is the true bearing turned by the watch's own heading.
    ///- Parameter Bearing: Degrees clockwise from north to the place.
    ///- Parameter Heading: Degrees clockwise from north the top of the watch points.
    static func RelativeBearing(Bearing: Double, Heading: Double) -> Double
    {
        let Wrapped = (Bearing - Heading).truncatingRemainder(dividingBy: 360.0)
        return Wrapped < 0.0 ? Wrapped + 360.0 : Wrapped
    }

    ///The farthest, in outer-ring radii from the center, that the arrow or the place's circle is drawn. Beyond this the place is far off
    ///the screen whatever the shape of the window, so there is no point in a longer arrow (a huge frame is slow to draw).
    static let MaxRadii = 20.0

    ///The length in points of the arrow, from the center of the radar to just short of the place's circle. The place is drawn at its
    ///true distance, so when it lies beyond the outer ring (or off the screen, zoomed in) the arrow runs past the ring, up to
    ///`MaxRadii` ring radii.
    ///- Parameter Distance: Meters to the place.
    ///- Parameter RangeDistance: Meters at the outer ring.
    ///- Parameter PlotRadius: Points from the center to the outer ring.
    ///- Parameter Clearance: Points to stop short of the circle's center (its radius and a gap).
    ///- Parameter MinimumLength: The shortest the arrow is drawn, so that a place at the center still has one.
    ///- Parameter MaxLength: The longest the arrow may be, so that its head stays on the screen when the place is off it; see
    ///  `DistanceToEdge`. The minimum length wins over it.
    static func ArrowLength(Distance: Double, RangeDistance: Double, PlotRadius: Double, Clearance: Double, MinimumLength: Double,
                            MaxLength: Double = .infinity) -> Double
    {
        guard RangeDistance > 0 else
        {
            return MinimumLength
        }
        let Ratio = min(max(Distance / RangeDistance, 0.0), MaxRadii)
        let Natural = max(PlotRadius * Ratio - Clearance, MinimumLength)
        return max(min(Natural, MaxLength), MinimumLength)
    }

    ///How far from the center of a rectangle a ray in a direction leaves it.
    ///- Parameter Angle: The direction in degrees clockwise from the top.
    ///- Parameter HalfWidth: Half the rectangle's width.
    ///- Parameter HalfHeight: Half the rectangle's height.
    static func DistanceToEdge(Angle: Double, HalfWidth: Double, HalfHeight: Double) -> Double
    {
        let Radians = Angle * .pi / 180.0
        let AcrossX = abs(sin(Radians))
        let AcrossY = abs(cos(Radians))
        let ToSide = AcrossX > 1e-9 ? HalfWidth / AcrossX : Double.infinity
        let ToTop = AcrossY > 1e-9 ? HalfHeight / AcrossY : Double.infinity
        return min(ToSide, ToTop)
    }

    ///Where the middle of the bearing label goes relative to the center of the radar: straight behind the arrow's base, on the
    ///reciprocal (180° the other way), far enough that the label's box clears the center marker.
    ///- Parameter Angle: The arrow's direction in degrees clockwise from the top of the screen.
    ///- Parameter HalfSize: Half the label's width and height.
    ///- Parameter Clearance: Points between the center and the nearest edge of the label.
    static func LabelOffset(Angle: Double, HalfSize: CGSize, Clearance: Double) -> CGSize
    {
        let Radians = Angle * .pi / 180.0
        //The arrow's unit direction on screen (y grows downward) is (sin, -cos); the label is on the opposite side.
        let BackX = -sin(Radians)
        let BackY = cos(Radians)
        let Reach = abs(BackX) * Double(HalfSize.width) + abs(BackY) * Double(HalfSize.height) + Clearance
        return CGSize(width: BackX * Reach, height: BackY * Reach)
    }
}
