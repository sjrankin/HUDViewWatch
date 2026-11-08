//
//  RadarArrow.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/8/26.
//

import SwiftUI

///An arrow pointing up whose base is at the bottom of its frame.
struct RadarArrowShape: Shape
{
    ///How long the head is, from the tip to where the shaft starts.
    let HeadLength: Double
    ///The width of the shaft.
    let ShaftWidth: Double

    func path(in Rect: CGRect) -> Path
    {
        let Middle = Rect.midX
        let Neck = Rect.minY + min(HeadLength, Rect.height)
        let Half = ShaftWidth / 2.0
        var Result = Path()
        Result.move(to: CGPoint(x: Middle, y: Rect.minY))
        Result.addLine(to: CGPoint(x: Rect.maxX, y: Neck))
        Result.addLine(to: CGPoint(x: Middle + Half, y: Neck))
        Result.addLine(to: CGPoint(x: Middle + Half, y: Rect.maxY))
        Result.addLine(to: CGPoint(x: Middle - Half, y: Rect.maxY))
        Result.addLine(to: CGPoint(x: Middle - Half, y: Neck))
        Result.addLine(to: CGPoint(x: Rect.minX, y: Neck))
        Result.closeSubpath()
        return Result
    }
}

///The radar's pointing mode: a bright yellow arrow from the center of the radar toward the chosen place, with the bearing to the place
///behind its base. Drawn centered on the radar's center, so it is laid over the same area as the rings.
struct RadarArrow: View
{
    ///Degrees clockwise from north to the place.
    let Bearing: Double
    ///Degrees clockwise from north the top of the watch points.
    let Heading: Double
    ///Meters to the place.
    let Distance: Double
    ///Meters at the outer ring.
    let RangeDistance: Double
    ///Points from the center to the outer ring.
    let PlotRadius: Double
    ///The diameter of a place's marker, which the arrow and the label are sized from.
    let IconSize: Double

    var body: some View
    {
        let Angle = RadarGuide.RelativeBearing(Bearing: Bearing, Heading: Heading)
        //Stop a little short of the circle so the arrow points at it rather than covering it.
        let Length = RadarGuide.ArrowLength(Distance: Distance, RangeDistance: RangeDistance, PlotRadius: PlotRadius,
                                            Clearance: IconSize * 0.7, MinimumLength: IconSize)
        let Width = IconSize * 1.3
        let Head = IconSize * 1.0
        let Shaft = IconSize * 0.38
        ZStack
        {
            ZStack
            {
                //A white outline outside a black one: the black sets the yellow off, and the white sets the arrow off the dark
                //background. The fill goes on last so only the outer halves of the strokes show.
                RadarArrowShape(HeadLength: Head, ShaftWidth: Shaft)
                    .stroke(.white, style: StrokeStyle(lineWidth: IconSize * 0.3, lineJoin: .round))
                RadarArrowShape(HeadLength: Head, ShaftWidth: Shaft)
                    .stroke(.black, style: StrokeStyle(lineWidth: IconSize * 0.15, lineJoin: .round))
                RadarArrowShape(HeadLength: Head, ShaftWidth: Shaft)
                    .fill(.yellow)
            }
            .frame(width: Width, height: Length)
            //Offset does not move the layout frame, so the rotation below turns the arrow about the center of the radar, where its
            //base is.
            .offset(y: Length / -2.0)
            .rotationEffect(.degrees(Angle))
            //On a translucent pill so it reads over the rings and places. Just clear of the center marker, close to the arrow's base.
            Text(HeadingFormat.Degrees(Angle))
                //Sized with the marker, so it keeps its proportions on the bigger iPhone radar.
                .font(.system(size: IconSize * 0.8, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, IconSize * 0.4)
                .padding(.vertical, IconSize * 0.12)
                .background(.black.opacity(0.55), in: .capsule)
                .offset(RadarGuide.LabelOffset(Angle: Angle, HalfSize: CGSize(width: IconSize * 1.3, height: IconSize * 0.55),
                                               Clearance: IconSize * 0.55))
        }
        .allowsHitTesting(false)
    }
}
