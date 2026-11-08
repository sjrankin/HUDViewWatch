//
//  HUDGuideArrowView.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/8/26.
//

import SwiftUI

///The arrow of the pointing mode: bright yellow when its tip is on the place, red when the place is out of view and the arrow only
///shows the way. A card behind its tail gives the place's name and distance.
struct HUDGuideArrowView: View
{
    let Arrow: HUDMath.GuideArrow
    let Unit: DistanceUnit
    ///Where the label may be: the label is kept inside it.
    let Bounds: CGRect
    ///Called when the place's circle is tapped, to stop pointing at the place.
    let OnDeselect: () -> Void

    ///How long the arrow is from tail to tip, in points.
    static let Length = 110.0
    ///The gap, in points, between the arrow's tip and the place's circle.
    static let CircleGap = 4.0
    ///The gap between the tail and the label, in points.
    static let LabelGap = 8.0

    ///The arrow pointing to the right with its tip at the origin, in points.
    static let Outline: Path =
    {
        var Shape = Path()
        Shape.move(to: CGPoint(x: 0, y: 0))
        Shape.addLine(to: CGPoint(x: -36, y: -28))
        Shape.addLine(to: CGPoint(x: -36, y: -11))
        Shape.addLine(to: CGPoint(x: -Length, y: -11))
        Shape.addLine(to: CGPoint(x: -Length, y: 11))
        Shape.addLine(to: CGPoint(x: -36, y: 11))
        Shape.addLine(to: CGPoint(x: -36, y: 28))
        Shape.closeSubpath()
        return Shape
    }()

    @State private var LabelSize = CGSize.zero

    var Tint: Color
    {
        Arrow.IsOffScreen ? .red : .yellow
    }

    var body: some View
    {
        ZStack
        {
            Canvas
            {
                Context, _ in
                Context.translateBy(x: Arrow.Tip.x, y: Arrow.Tip.y)
                Context.rotate(by: .radians(Arrow.Angle))
                Context.addFilter(.shadow(color: .black.opacity(0.6), radius: 4))
                Context.fill(HUDGuideArrowView.Outline, with: .color(Tint))
                Context.stroke(HUDGuideArrowView.Outline, with: .color(.black.opacity(0.85)),
                               style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
            .allowsHitTesting(false)
            //The place's circle, as in the normal view, when the place is in view.
            if let Spot = Arrow.Spot
            {
                //Tapping it stops pointing at the place; the touch area is bigger than the circle.
                Button(action: OnDeselect)
                {
                    Circle()
                        .fill(Arrow.Kind.MarkerColor)
                        .frame(width: HUDMarkerView.DotSize, height: HUDMarkerView.DotSize)
                        .overlay { Circle().stroke(.white, lineWidth: 2) }
                        .shadow(color: .black.opacity(0.5), radius: 3)
                        .frame(width: HUDMarkerView.DotSize * 3, height: HUDMarkerView.DotSize * 3)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop tracking \(Arrow.Name)")
                .position(Spot)
            }
            VStack(spacing: 2)
            {
                Text(Arrow.Name)
                    .font(.caption.bold())
                if Arrow.Kind != .Constellation
                {
                    Text(DistanceFormat.Short(Meters: Arrow.Distance, Unit: Unit))
                        .font(.caption2)
                }
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.92), in: .rect(cornerRadius: 8))
            .overlay
            {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Tint, lineWidth: 2)
            }
            .fixedSize()
            .onGeometryChange(for: CGSize.self)
            {
                $0.size
            }
            action:
            {
                LabelSize = $0
            }
            .position(LabelCenter)
            //Not shown until measured, so it does not jump from the wrong place.
            .opacity(LabelSize == .zero ? 0.0 : 1.0)
            .allowsHitTesting(false)
        }
    }

    ///Where the middle of the label goes: behind the arrow's tail, as far back as it takes for the label to clear it, and then kept
    ///inside the bounds.
    var LabelCenter: CGPoint
    {
        HUDGuideArrowView.LabelCenter(Arrow: Arrow, LabelSize: LabelSize, Bounds: Bounds)
    }

    static func LabelCenter(Arrow: HUDMath.GuideArrow, LabelSize: CGSize, Bounds: CGRect) -> CGPoint
    {
        let Half = CGSize(width: LabelSize.width / 2.0, height: LabelSize.height / 2.0)
        //How far from the tail the center has to be so that the label's box does not touch the arrow, whichever way it points.
        let Back = abs(Arrow.Direction.x) * Half.width + abs(Arrow.Direction.y) * Half.height + LabelGap
        let Behind = Length + Back
        let X = Arrow.Tip.x - Arrow.Direction.x * Behind
        let Y = Arrow.Tip.y - Arrow.Direction.y * Behind
        let MinX = Bounds.minX + Half.width
        let MaxX = max(MinX, Bounds.maxX - Half.width)
        let MinY = Bounds.minY + Half.height
        let MaxY = max(MinY, Bounds.maxY - Half.height)
        return CGPoint(x: min(max(X, MinX), MaxX), y: min(max(Y, MinY), MaxY))
    }
}
