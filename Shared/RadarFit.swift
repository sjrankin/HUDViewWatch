//
//  RadarFit.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//

import Foundation

///Works out how large the radar can be drawn so that it, cardinal letters included, stays on the screen.
enum RadarFit
{
    ///Points from the radar's center to the outer edge of a cardinal letter, at a Scale of 1: the letters sit 96 from the center
    ///and are about 10 across.
    static let HalfExtent = 102.0

    ///The largest Scale (up to `Maximum`) at which the radar fits the given space. The radar is centered, then moved down by
    ///`TopInset`, so the bottom is the tightest edge on a small screen.
    ///- Parameter Available: The size of the space the radar is laid out in (the whole screen on the watch), in points.
    ///- Parameter TopInset: Points the radar is moved down.
    ///- Parameter EdgeMargin: Points to leave between the letters and the edge of the space.
    ///- Parameter Maximum: The Scale to use when there is room (1 is the layout the watch was designed with).
    static func Scale(Available: CGSize, TopInset: Double, EdgeMargin: Double = 4, Maximum: Double = 1.0) -> Double
    {
        guard Available.width > 0, Available.height > 0 else
        {
            return Maximum
        }
        let Vertical = (Available.height / 2 - TopInset - EdgeMargin) / HalfExtent
        let Horizontal = (Available.width / 2 - EdgeMargin) / HalfExtent
        return min(Maximum, max(0.25, min(Vertical, Horizontal)))
    }
}
