//
//  HUDMarkerView.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//  Ported from POIMarkerView in HUDViewUI.
//

import SwiftUI

///One place on the camera view: a dot at the exact spot, with a card of the icon, name and distance below it.
struct HUDMarkerView: View
{
    let Item: POIFinder.VisiblePOI
    let Unit: DistanceUnit
    let IsSelected: Bool

    static let DotSize = 16.0

    var body: some View
    {
        VStack(spacing: 4)
        {
            Circle()
                .fill(Item.Place.Kind.MarkerColor)
                .frame(width: HUDMarkerView.DotSize, height: HUDMarkerView.DotSize)
                .overlay { Circle().stroke(.white, lineWidth: IsSelected ? 4 : 2) }
                .shadow(color: .black.opacity(0.5), radius: 3)
            VStack(spacing: 3)
            {
                Image(systemName: Item.Place.Kind.Icon)
                    .foregroundStyle(Item.Place.Kind.MarkerColor)
                Text(Item.Place.Name)
                    .font(.caption.bold())
                Text(DistanceFormat.Short(Meters: Item.Distance, Unit: Unit))
                    .font(.caption2)
                    .foregroundStyle(.black.opacity(0.8))
                if IsSelected
                {
                    HUDMarkerDetails(Item: Item, Unit: Unit)
                }
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            //Wide enough for the longest detail line once expanded.
            .frame(minWidth: IsSelected ? 190 : nil)
            .background(.white.opacity(IsSelected ? 0.95 : 0.85), in: .rect(cornerRadius: 8))
            .overlay
            {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Item.Place.Kind.MarkerColor.opacity(IsSelected ? 1.0 : 0.65), lineWidth: IsSelected ? 3 : 1)
            }
        }
        .fixedSize()
        .opacity(IsSelected ? 1.0 : HUDMath.Opacity(Distance: Item.Distance))
        .animation(.snappy, value: IsSelected)
    }
}
