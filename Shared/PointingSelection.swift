//
//  PointingSelection.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/8/26.
//

import Foundation

///How a tap on the radar changes the selected place while the pointing mode is in use.
enum PointingSelection
{
    ///The hint shown while the pointer mode is on and no place is chosen: on the HUD, the iPhone radar and the watch.
    static let Hint = "Tap a place to track"

    ///The selection after a tap.
    ///
    ///Normally a tap selects the place under it, or clears the selection when it hits no place. While an arrow is showing, a tap that
    ///misses the target does nothing, so a stray touch does not lose the arrow; tapping the target itself clears it, which brings back
    ///all the places so another can be chosen.
    ///- Parameter Current: The selected place.
    ///- Parameter Picked: The place under the tap, if any.
    ///- Parameter IsPointing: True when the pointing mode is on.
    ///- Parameter HasTarget: True when an arrow is showing.
    static func AfterTap(Current: UUID?, Picked: UUID?, IsPointing: Bool, HasTarget: Bool) -> UUID?
    {
        guard IsPointing, HasTarget else
        {
            return Picked
        }
        if let Picked, Picked == Current
        {
            return nil
        }
        return Current
    }
}
