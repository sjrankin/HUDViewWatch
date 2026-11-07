//
//  PlaceDraft.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/4/26.
//

import Foundation
import Observation

///A place being entered or edited. Fields are optional while the user types; `Make` gives the finished place once they are valid.
@MainActor
@Observable
final class PlaceDraft: Identifiable
{
    ///Identifies the draft for the sheet that edits it.
    let id = UUID()
    ///The id of the place being edited, or `nil` for a new place.
    let PlaceID: UUID?
    var Name: String
    var Kind: POIType
    var Latitude: Double?
    var Longitude: Double?
    var Elevation: Double?
    var Population: Int?
    ///A short note about the place; empty for none.
    var Note: String
    ///True to plot the place on the radar.
    var IsVisible: Bool

    ///A blank draft for a new place.
    init()
    {
        PlaceID = nil
        Name = ""
        Kind = .City
        Note = ""
        IsVisible = true
    }

    ///A draft that edits `Place`.
    init(Editing Place: POI)
    {
        PlaceID = Place.id
        Name = Place.Name
        Kind = Place.Kind
        Latitude = Place.Latitude
        Longitude = Place.Longitude
        Elevation = Place.Elevation
        Population = Place.Population
        Note = Place.Description ?? ""
        IsVisible = Place.IsVisible
    }

    var IsNew: Bool
    {
        PlaceID == nil
    }

    ///The place, or `nil` if the name is blank or the coordinate is missing or off the globe.
    func Make() -> POI?
    {
        guard let Latitude, let Longitude else
        {
            return nil
        }
        let Place = POI(ID: PlaceID ?? UUID(), Name: Name.trimmingCharacters(in: .whitespacesAndNewlines),
                        Latitude: Latitude, Longitude: Longitude, Kind: Kind,
                        Elevation: Elevation, Population: Population,
                        Description: Note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : Note.trimmingCharacters(in: .whitespacesAndNewlines),
                        IsVisible: IsVisible)
        return Place.IsValid ? Place : nil
    }

    var IsValid: Bool
    {
        Make() != nil
    }

    ///Why the draft cannot be saved yet, in words for the user; `nil` when it can.
    var Problem: String?
    {
        if Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return "Enter a name."
        }
        guard let Latitude, let Longitude else
        {
            return "Enter a latitude and a longitude."
        }
        if (-90.0 ... 90.0).contains(Latitude) == false
        {
            return "Latitude must be between -90 and 90."
        }
        if (-180.0 ... 180.0).contains(Longitude) == false
        {
            return "Longitude must be between -180 and 180."
        }
        return nil
    }
}
