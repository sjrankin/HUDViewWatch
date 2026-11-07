//
//  CompassBarView.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//  Ported from CompassBarView in HUDViewUI.
//

import SwiftUI

///A strip of the sixteen compass points that slides as the camera turns, with a red mark at the middle for the way it faces.
struct CompassBarView: View
{
    ///The way the camera faces, in degrees from north.
    let Heading: Double
    ///How many degrees the bar's width shows.
    var FieldOfView: Double = 180.0

    var body: some View
    {
        Canvas
        {
            Context, Size in
            guard FieldOfView > 0, Size.width > 0 else
            {
                return
            }
            let PerDegree = Size.width / FieldOfView
            let CenterX = Size.width / 2.0
            let HalfWidth = Size.width / 2.0
            for Point in HUDMath.CompassPoints
            {
                let Offset = POIFinder.AngleDifference(From: Heading, To: Point.Bearing) * PerDegree
                if abs(Offset) > HalfWidth
                {
                    continue
                }
                let IsCardinal = Point.Bearing.truncatingRemainder(dividingBy: 90.0) == 0.0
                let Away = abs(Offset)
                let Alpha = Away < HalfWidth * 0.7 ? 1.0 : (Away < HalfWidth ? 0.7 : 0.3)
                let X = CenterX + Offset
                let Tick = IsCardinal ? 15.0 : 10.0
                let Name = Text(Point.Name)
                    .font(IsCardinal ? .title3.bold() : .subheadline)
                    .foregroundStyle(.white.opacity(Alpha))
                Context.draw(Name, at: CGPoint(x: X, y: Size.height - 4), anchor: .bottom)
                var Mark = Path()
                Mark.move(to: CGPoint(x: X, y: Size.height - 30))
                Mark.addLine(to: CGPoint(x: X, y: Size.height - 30 - Tick))
                Context.stroke(Mark, with: .color(.white.opacity(Alpha)), lineWidth: 2)
            }
            var Center = Path()
            Center.move(to: CGPoint(x: CenterX, y: Size.height))
            Center.addLine(to: CGPoint(x: CenterX, y: Size.height - 24))
            Context.stroke(Center, with: .color(.red), lineWidth: 3)
        }
        .accessibilityHidden(true)
    }
}
