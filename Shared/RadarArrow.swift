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
    ///How much larger than standard to draw the arrow (1 is the iPhone and watch size). The shaft and the outline grow a little more
    ///than the length, so a larger arrow is also bolder.
    var Scale: Double = 1.0
    ///The size of the area the radar is drawn in, or `.zero` if not known. The arrow is cut short so that its head stays inside it
    ///when the place is off the screen (zoomed in).
    var ViewSize: CGSize = .zero
    ///How much to narrow (below 1) or widen the arrow and its head, without changing its length.
    var WidthScale: Double = 1.0

    var body: some View
    {
        let Angle = RadarGuide.RelativeBearing(Bearing: Bearing, Heading: Heading)
        //Stop a little short of the circle so the arrow points at it rather than covering it.
        //Room for the arrow along its direction: to the edge of the view, less a margin for the head's outline.
        let Room = ViewSize == .zero ? Double.infinity
            : RadarGuide.DistanceToEdge(Angle: Angle, HalfWidth: ViewSize.width / 2, HalfHeight: ViewSize.height / 2) - IconSize * 0.5
        let Length = RadarGuide.ArrowLength(Distance: Distance, RangeDistance: RangeDistance, PlotRadius: PlotRadius,
                                            Clearance: IconSize * 0.7, MinimumLength: IconSize * Scale, MaxLength: Room)
        let Bold = Scale > 1.0 ? 1.25 : 1.0
        let Width = IconSize * 1.3 * Scale * WidthScale
        let Head = IconSize * 1.0 * Scale
        let Shaft = IconSize * 0.38 * Scale * Bold * WidthScale
        ZStack
        {
            ZStack
            {
                //A white outline outside a black one: the black sets the yellow off, and the white sets the arrow off the dark
                //background. The fill goes on last so only the outer halves of the strokes show.
                RadarArrowShape(HeadLength: Head, ShaftWidth: Shaft)
                    .stroke(.white, style: StrokeStyle(lineWidth: IconSize * 0.3 * Bold, lineJoin: .round))
                RadarArrowShape(HeadLength: Head, ShaftWidth: Shaft)
                    .stroke(.black, style: StrokeStyle(lineWidth: IconSize * 0.15 * Bold, lineJoin: .round))
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
                //Never wrapped: the frame below is tiny, and would otherwise squeeze the degree sign onto a second line.
                .fixedSize()
                .offset(RadarGuide.LabelOffset(Angle: Angle, HalfSize: CGSize(width: IconSize * 1.3, height: IconSize * 0.55),
                                               Clearance: IconSize * 0.55))
        }
        //Takes no room in the layout, however long the arrow is: a long one made the radar taller and pushed the slider off the screen.
        .frame(width: 1, height: 1)
        .allowsHitTesting(false)
    }
}
