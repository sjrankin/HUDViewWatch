//
//  RadarMathTests.swift
//  HUDViewWatchTests
//
//  Created by Stuart Rankin on 11/4/26.
//

import CoreLocation
import Foundation
import Testing
@testable import HUDViewWatch

struct RadarMathTests
{
    @Test func SpreadingTheFingersToTwiceTheDistanceHalvesTheRange()
    {
        let Ratio = 0.0025
        let Start = 0.2314
        let After = PinchZoom.Zoom(Start: Start, Magnification: 2.0)
        let RangeBefore = 800_000 * pow(Ratio, Start)
        let RangeAfter = 800_000 * pow(Ratio, After)
        #expect(abs(RangeAfter - RangeBefore / 2.0) < 1.0)
    }

    @Test func ZoomStaysWithinItsLimits()
    {
        #expect(PinchZoom.Zoom(Start: 0.9, Magnification: 1000) == 1.0)
        #expect(PinchZoom.Zoom(Start: 0.1, Magnification: 0.0001) == 0.0)
        #expect(PinchZoom.Zoom(Start: 0.5, Magnification: 1.0) == 0.5)
    }

    @Test func FinderIncludesTheUsersPlacesInRangeFarthestFirst()
    {
        let Here = CLLocation(latitude: 38.0, longitude: -121.0)
        let Near = POI(Name: "Near", Latitude: 38.01, Longitude: -121.0, Kind: .Test)
        let Middle = POI(Name: "Middle", Latitude: 38.5, Longitude: -121.0, Kind: .Test)
        let Far = POI(Name: "Far", Latitude: 10.0, Longitude: -121.0, Kind: .Test)
        let Found = POIFinder.POIs(In: [Near, Middle, Far], Near: Here, MaxDistance: 200_000)
        #expect(Found.map { $0.Place.Name } == ["Middle", "Near"])
    }

    @Test func BearingDueEastIsNinetyDegrees()
    {
        let Start = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let End = CLLocationCoordinate2D(latitude: 0, longitude: 1)
        #expect(abs(POIFinder.Bearing(From: Start, To: End) - 90.0) < 0.001)
    }
}

struct HeadingFormatTests
{
    @Test func HeadingsRoundToWholeDegrees()
    {
        #expect(HeadingFormat.Degrees(274.4) == "274°")
        #expect(HeadingFormat.Degrees(274.6) == "275°")
        #expect(HeadingFormat.Degrees(0) == "0°")
    }

    @Test func HeadingJustUnderFullCircleShowsZero()
    {
        #expect(HeadingFormat.Degrees(359.6) == "0°")
        #expect(HeadingFormat.Degrees(360) == "0°")
    }

    @Test func OutOfRangeHeadingsWrap()
    {
        #expect(HeadingFormat.Degrees(-10) == "350°")
        #expect(HeadingFormat.Degrees(725) == "5°")
        #expect(HeadingFormat.Degrees(.nan) == "--°")
    }
}

struct RadarFitTests
{
    @Test func ABigScreenKeepsTheFullSizedRadar()
    {
        //46 mm watch, 208 x 248 points: the design size fits, give or take a few percent.
        let Scale = RadarFit.Scale(Available: CGSize(width: 208, height: 248), TopInset: 16)
        #expect(Scale > 0.95 && Scale <= 1.0)
        #expect(RadarFit.Scale(Available: CGSize(width: 400, height: 600), TopInset: 16) == 1.0)
    }

    @Test func ASmallScreenShrinksTheRadarSoTheLettersFit()
    {
        //40 mm watch, 162 x 197 points.
        let Size = CGSize(width: 162, height: 197)
        let Scale = RadarFit.Scale(Available: Size, TopInset: 16)
        #expect(Scale < 0.8)
        //The bottom letter, after the radar is centered and moved down, stays on the screen.
        let Bottom = Size.height / 2 + 16 + RadarFit.HalfExtent * Scale
        #expect(Bottom <= Size.height)
        //And the side letters stay inside the width.
        #expect(RadarFit.HalfExtent * Scale <= Size.width / 2)
    }

    @Test func UnknownOrTinySpacesGiveASaneScale()
    {
        #expect(RadarFit.Scale(Available: CGSize(width: 0, height: 0), TopInset: 16) == 1.0)
        let Tiny = RadarFit.Scale(Available: CGSize(width: 20, height: 20), TopInset: 16)
        #expect(Tiny == 0.25)
    }
}
