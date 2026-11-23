//
//  RadarGuideTests.swift
//  HUDViewWatchTests
//
//  Created by Stuart Rankin on 11/8/26.
//

import CoreGraphics
import Testing
@testable import HUDViewWatch

struct RadarGuideTests
{
    @Test func BearingIsRelativeToWhereTheWatchFaces()
    {
        #expect(RadarGuide.RelativeBearing(Bearing: 90, Heading: 90) == 0)
        #expect(RadarGuide.RelativeBearing(Bearing: 90, Heading: 0) == 90)
        #expect(RadarGuide.RelativeBearing(Bearing: 10, Heading: 350) == 20)
        #expect(RadarGuide.RelativeBearing(Bearing: 350, Heading: 10) == 340)
        #expect(RadarGuide.RelativeBearing(Bearing: 0, Heading: 180) == 180)
    }

    @Test func ArrowStopsShortOfTheCircle()
    {
        let Length = RadarGuide.ArrowLength(Distance: 50_000, RangeDistance: 100_000, PlotRadius: 80, Clearance: 10, MinimumLength: 14)
        #expect(Length == 30)
    }

    @Test func APlaceBeyondTheRingGetsAnArrowPastTheRing()
    {
        //Five ring radii out: 5 * 80 = 400 points, less the clearance.
        let Length = RadarGuide.ArrowLength(Distance: 500_000, RangeDistance: 100_000, PlotRadius: 80, Clearance: 10, MinimumLength: 14)
        #expect(Length == 390)
    }

    @Test func AVeryFarPlaceGetsAnArrowOfLimitedLength()
    {
        let Length = RadarGuide.ArrowLength(Distance: 50_000_000, RangeDistance: 100_000, PlotRadius: 80, Clearance: 10, MinimumLength: 14)
        #expect(Length == 80 * RadarGuide.MaxRadii - 10)
    }

    @Test func APlaceAtTheCenterStillGetsAnArrow()
    {
        let Length = RadarGuide.ArrowLength(Distance: 0, RangeDistance: 100_000, PlotRadius: 80, Clearance: 10, MinimumLength: 14)
        #expect(Length == 14)
    }

    @Test func TheArrowIsCutShortToKeepItsHeadOnScreen()
    {
        let Length = RadarGuide.ArrowLength(Distance: 50_000_000, RangeDistance: 100_000, PlotRadius: 80, Clearance: 10, MinimumLength: 14,
                                            MaxLength: 200)
        #expect(Length == 200)
        //A tiny view never makes it shorter than the minimum.
        let Tiny = RadarGuide.ArrowLength(Distance: 50_000_000, RangeDistance: 100_000, PlotRadius: 80, Clearance: 10, MinimumLength: 14,
                                          MaxLength: 5)
        #expect(Tiny == 14)
    }

    @Test func DistanceToTheEdgeOfARectangle()
    {
        //Straight up and sideways reach the nearest side; a diagonal reaches a corner or a side, whichever comes first.
        #expect(abs(RadarGuide.DistanceToEdge(Angle: 0, HalfWidth: 100, HalfHeight: 50) - 50) < 0.001)
        #expect(abs(RadarGuide.DistanceToEdge(Angle: 90, HalfWidth: 100, HalfHeight: 50) - 100) < 0.001)
        #expect(abs(RadarGuide.DistanceToEdge(Angle: 180, HalfWidth: 100, HalfHeight: 50) - 50) < 0.001)
        #expect(abs(RadarGuide.DistanceToEdge(Angle: 45, HalfWidth: 50, HalfHeight: 50) - 50 * 2.0.squareRoot()) < 0.001)
        #expect(abs(RadarGuide.DistanceToEdge(Angle: 45, HalfWidth: 100, HalfHeight: 50) - 50 * 2.0.squareRoot()) < 0.001)
    }

    @Test func TheLabelIsOnTheReciprocalOfTheArrow()
    {
        let Half = CGSize(width: 20, height: 8)
        //Arrow straight up: the label is straight down.
        let Up = RadarGuide.LabelOffset(Angle: 0, HalfSize: Half, Clearance: 5)
        #expect(abs(Up.width) < 0.001)
        #expect(abs(Up.height - 13) < 0.001)
        //Arrow to the right: the label is to the left.
        let Right = RadarGuide.LabelOffset(Angle: 90, HalfSize: Half, Clearance: 5)
        #expect(abs(Right.width + 25) < 0.001)
        #expect(abs(Right.height) < 0.001)
        //Arrow straight down: the label is straight up.
        let Down = RadarGuide.LabelOffset(Angle: 180, HalfSize: Half, Clearance: 5)
        #expect(abs(Down.height + 13) < 0.001)
    }
}
