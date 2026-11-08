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

    ///The length in points of the arrow, from the center of the radar to just short of the place's circle. A place beyond the outer ring
    ///is drawn on it, so the arrow never runs longer than the ring's radius.
    ///- Parameter Distance: Meters to the place.
    ///- Parameter RangeDistance: Meters at the outer ring.
    ///- Parameter PlotRadius: Points from the center to the outer ring.
    ///- Parameter Clearance: Points to stop short of the circle's center (its radius and a gap).
    ///- Parameter MinimumLength: The shortest the arrow is drawn, so that a place at the center still has one.
    static func ArrowLength(Distance: Double, RangeDistance: Double, PlotRadius: Double, Clearance: Double, MinimumLength: Double) -> Double
    {
        guard RangeDistance > 0 else
        {
            return MinimumLength
        }
        let Ratio = min(max(Distance / RangeDistance, 0.0), 1.0)
        return max(PlotRadius * Ratio - Clearance, MinimumLength)
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
