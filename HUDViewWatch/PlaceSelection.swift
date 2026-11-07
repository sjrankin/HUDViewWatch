//
//  PlaceSelection.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//

import Foundation
import Observation

///The place the user tapped, shared by the camera view and the radar so that choosing a place in one highlights it in the other.
@MainActor
@Observable
final class PlaceSelection
{
    var SelectedID: UUID? = nil

    ///Selects a place, or clears the selection if it is the one already selected.
    func Toggle(_ ID: UUID)
    {
        SelectedID = SelectedID == ID ? nil : ID
    }
}
