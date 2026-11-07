//
//  PinchZoom.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/4/26.
//

import Foundation

///Turns a pinch into the radar's zoom position. The radar's range is `MaxDistance * MinRangeRatio^Zoom`, so spreading the fingers
///to twice the distance (magnification 2) should halve the range: Zoom grows by ln(2) / -ln(MinRangeRatio).
enum PinchZoom
{
    ///The zoom position after a pinch that started at `Start`, kept within 0 ... 1.
    static func Zoom(Start: Double, Magnification: Double, MinRangeRatio: Double = 0.0025) -> Double
    {
        guard Magnification > 0 else
        {
            return min(max(Start, 0.0), 1.0)
        }
        let Change = log(Magnification) / -log(MinRangeRatio)
        return min(max(Start + Change, 0.0), 1.0)
    }
}
