//
//  HeadingFormat.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//

import Foundation

///Formats compass headings for display.
enum HeadingFormat
{
    ///The heading rounded to whole degrees, 0 through 359, e.g. "274°". Values just under 360 round to 0, not 360, and values
    ///outside 0 ..< 360 are wrapped into it.
    static func Degrees(_ Heading: Double) -> String
    {
        guard Heading.isFinite else
        {
            return "--°"
        }
        let Whole = Int(Heading.rounded())
        let Wrapped = ((Whole % 360) + 360) % 360
        return "\(Wrapped)°"
    }
}
