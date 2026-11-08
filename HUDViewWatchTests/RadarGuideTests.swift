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

    @Test func APlaceBeyondTheRingGetsAnArrowToTheRing()
    {
        let Length = RadarGuide.ArrowLength(Distance: 500_000, RangeDistance: 100_000, PlotRadius: 80, Clearance: 10, MinimumLength: 14)
        #expect(Length == 70)
    }

    @Test func APlaceAtTheCenterStillGetsAnArrow()
    {
        let Length = RadarGuide.ArrowLength(Distance: 0, RangeDistance: 100_000, PlotRadius: 80, Clearance: 10, MinimumLength: 14)
        #expect(Length == 14)
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
