//
//  RadarDeclutterTests.swift
//  HUDViewWatchTests
//
//  Created by Stuart Rankin on 11/7/26.
//

import Foundation
import Testing
@testable import HUDViewWatch

struct RadarDeclutterTests
{
    ///Outer ring at 100 km, 80 points from the center, markers 14 points across.
    private let Range = 100_000.0
    private let Radius = 80.0
    private let Spacing = 14.0

    private func Make(_ Name: String, Kind: POIType = .Test, Distance: Double, Bearing: Double = 0) -> POIFinder.VisiblePOI
    {
        POIFinder.VisiblePOI(Place: POI(Name: Name, Latitude: 0, Longitude: 0, Kind: Kind), Distance: Distance, Bearing: Bearing)
    }

    private func Names(_ Items: [POIFinder.VisiblePOI], User: Set<UUID> = [], Selected: UUID? = nil, Clamp: Bool = true) -> [String]
    {
        RadarDeclutter.Visible(Items, UserPlaceIDs: User, SelectedID: Selected, RangeDistance: Range,
                               PlotRadius: Radius, ClampsToRange: Clamp, MinSpacing: Spacing).map { $0.Place.Name }
    }

    @Test func HalfOverlapMeansCentersMayBeHalfAMarkerApart()
    {
        #expect(RadarDeclutter.Spacing(IconSize: 14) == 7)
        #expect(RadarDeclutter.Spacing(IconSize: 14, Overlap: 0) == 14)
        #expect(RadarDeclutter.Spacing(IconSize: 14, Overlap: 1) == 0)
    }

    @Test func PlacesOverlappingByLessThanHalfAreBothKept()
    {
        let Spacing = RadarDeclutter.Spacing(IconSize: 14)
        //10 points apart: overlapping by 4 of 14, less than half, so both stay. 5 points apart: more than half, so one goes.
        let Apart = [Make("A", Distance: 0), Make("B", Distance: 10.0 / Radius * Range)]
        let Close = [Make("A", Distance: 0), Make("B", Distance: 5.0 / Radius * Range)]
        func Count(_ Items: [POIFinder.VisiblePOI]) -> Int
        {
            RadarDeclutter.Visible(Items, UserPlaceIDs: [], SelectedID: nil, RangeDistance: Range,
                                   PlotRadius: Radius, ClampsToRange: true, MinSpacing: Spacing).count
        }
        #expect(Count(Apart) == 2)
        #expect(Count(Close) == 1)
    }

    @Test func PlacesFarApartAreAllKept()
    {
        let Items = [Make("A", Distance: 50_000, Bearing: 0), Make("B", Distance: 50_000, Bearing: 180)]
        #expect(Names(Items) == ["A", "B"])
    }

    @Test func OverlappingPlacesKeepOnlyTheNearest()
    {
        //Both about 1 point apart near the center.
        let Items = [Make("Far", Distance: 5_000, Bearing: 0), Make("Near", Distance: 4_000, Bearing: 0)]
        #expect(Names(Items) == ["Near"])
    }

    @Test func CitiesBeatOtherBuiltInPlaces()
    {
        let Items = [Make("Lake", Kind: .Lake, Distance: 4_000), Make("Town", Kind: .City, Distance: 5_000)]
        #expect(Names(Items) == ["Town"])
    }

    @Test func UserPlacesBeatBuiltInCitiesEvenWhenFarther()
    {
        let Mine = Make("Mine", Kind: .Test, Distance: 6_000)
        let Items = [Mine, Make("Town", Kind: .City, Distance: 2_000)]
        #expect(Names(Items, User: [Mine.id]) == ["Mine"])
    }

    @Test func TheSelectedPlaceIsNeverDropped()
    {
        let Picked = Make("Picked", Kind: .Lake, Distance: 6_000)
        let Items = [Picked, Make("Mine", Distance: 2_000)]
        #expect(Names(Items, User: [Items[1].id], Selected: Picked.id) == ["Picked"])
    }

    @Test func OriginalDrawOrderIsPreserved()
    {
        let Items = [Make("Far", Distance: 90_000, Bearing: 90), Make("Mid", Distance: 50_000, Bearing: 180), Make("Near", Distance: 20_000, Bearing: 270)]
        #expect(Names(Items) == ["Far", "Mid", "Near"])
    }

    @Test func ZoomingInSeparatesPlacesThatOverlappedBefore()
    {
        let Items = [Make("A", Distance: 5_000, Bearing: 0), Make("B", Distance: 9_000, Bearing: 0)]
        #expect(Names(Items).count == 1)
        //A tenth of the range puts the same places ten times farther apart on screen.
        let Closer = RadarDeclutter.Visible(Items, UserPlaceIDs: [], SelectedID: nil, RangeDistance: Range / 10,
                                            PlotRadius: Radius, ClampsToRange: true, MinSpacing: Spacing)
        #expect(Closer.count == 2)
    }

    @Test func PlacesPastTheRingStackOnTheRingWhenClamped()
    {
        //Same bearing, both beyond the range: both sit at the ring, so one is dropped. Unclamped they are 60 points apart.
        let Items = [Make("A", Distance: 150_000), Make("B", Distance: 200_000)]
        #expect(Names(Items, Clamp: true).count == 1)
        #expect(Names(Items, Clamp: false).count == 2)
    }

    @Test func NegativeCoordinatesLandInTheRightCell()
    {
        //Cells are indexed by rounding down, so places straddling zero must still be seen as neighbors.
        let Items = [Make("West", Distance: 1_000, Bearing: 270), Make("East", Distance: 1_000, Bearing: 90)]
        #expect(Names(Items).count == 1)
    }
}
