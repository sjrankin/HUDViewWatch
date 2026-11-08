//
//  HUDPlacedMarker.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//

import SwiftUI

///One marker put on the camera view so that its dot, not the middle of the whole card, sits on the spot. The marker keeps its real size
///(a zero-size frame would leave the card outside the area that can be tapped). It is centered across the view with its top edge at
///the view's top, then shifted to the spot, so it grows downward from the dot when it expands.
struct HUDPlacedMarker: View
{
    let Entry: HUDMath.Placement
    let Unit: DistanceUnit
    let IsSelected: Bool
    ///The size of the view the marker is placed on.
    let Area: CGSize
    let OnSelect: (UUID) -> Void

    var body: some View
    {
        Button
        {
            OnSelect(Entry.id)
        }
        label:
        {
            HUDMarkerView(Item: Entry.Item, Unit: Unit, IsSelected: IsSelected)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        //The dot is at the top of the marker, DotSize / 2 from its center.
        .offset(x: Entry.Point.x - Area.width / 2, y: Entry.Point.y - HUDMarkerView.DotSize / 2)
        //Nearest on top, and the tapped one above all.
        .zIndex(IsSelected ? 1.0 : -Entry.Item.Distance)
    }
}
