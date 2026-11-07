//
//  PlaceDraftTests.swift
//  HUDViewWatchTests
//
//  Created by Stuart Rankin on 11/4/26.
//

import Foundation
import Testing
@testable import HUDViewWatch

@MainActor
struct PlaceDraftTests
{
    @Test func ABlankDraftIsNotValid()
    {
        let Draft = PlaceDraft()
        #expect(Draft.IsValid == false)
        #expect(Draft.Problem == "Enter a name.")
    }

    @Test func ANamedDraftNeedsACoordinate()
    {
        let Draft = PlaceDraft()
        Draft.Name = "Cabin"
        #expect(Draft.Problem == "Enter a latitude and a longitude.")
        Draft.Latitude = 39.0
        #expect(Draft.IsValid == false)
    }

    @Test func CoordinatesMustBeOnTheGlobe()
    {
        let Draft = PlaceDraft()
        Draft.Name = "Nowhere"
        Draft.Latitude = 91
        Draft.Longitude = 0
        #expect(Draft.Problem == "Latitude must be between -90 and 90.")
        Draft.Latitude = 0
        Draft.Longitude = -181
        #expect(Draft.Problem == "Longitude must be between -180 and 180.")
        Draft.Longitude = -180
        #expect(Draft.IsValid)
    }

    @Test func AValidDraftMakesATrimmedPlace()
    {
        let Draft = PlaceDraft()
        Draft.Name = "  Cabin  "
        Draft.Kind = .Forest
        Draft.Latitude = 39.1
        Draft.Longitude = -120.2
        Draft.Elevation = 1800
        let Place = Draft.Make()
        #expect(Place?.Name == "Cabin")
        #expect(Place?.Kind == .Forest)
        #expect(Place?.Elevation == 1800)
        #expect(Draft.IsNew)
    }

    @Test func EditingKeepsThePlaceID()
    {
        let Original = POI(Name: "Home", Latitude: 38, Longitude: -121, Kind: .Test)
        let Draft = PlaceDraft(Editing: Original)
        Draft.Name = "Home Sweet Home"
        #expect(Draft.IsNew == false)
        #expect(Draft.Make()?.id == Original.id)
        #expect(Draft.Make()?.Name == "Home Sweet Home")
    }
}
