//
//  PointingSelectionTests.swift
//  HUDViewWatchTests
//
//  Created by Stuart Rankin on 11/8/26.
//

import Foundation
import Testing
@testable import HUDViewWatch

struct PointingSelectionTests
{
    private let A = UUID()
    private let B = UUID()

    @Test func TheHintIsOneStringEverywhere()
    {
        #expect(PointingSelection.Hint == "Tap a place to track")
    }

    @Test func NormallyATapSelectsOrClears()
    {
        #expect(PointingSelection.AfterTap(Current: nil, Picked: A, IsPointing: false, HasTarget: false) == A)
        #expect(PointingSelection.AfterTap(Current: A, Picked: B, IsPointing: false, HasTarget: false) == B)
        #expect(PointingSelection.AfterTap(Current: A, Picked: nil, IsPointing: false, HasTarget: false) == nil)
    }

    @Test func PointingWithNoTargetStillSelects()
    {
        #expect(PointingSelection.AfterTap(Current: nil, Picked: A, IsPointing: true, HasTarget: false) == A)
        #expect(PointingSelection.AfterTap(Current: nil, Picked: nil, IsPointing: true, HasTarget: false) == nil)
    }

    @Test func AStrayTapKeepsTheArrow()
    {
        #expect(PointingSelection.AfterTap(Current: A, Picked: nil, IsPointing: true, HasTarget: true) == A)
    }

    @Test func TappingTheTargetClearsIt()
    {
        #expect(PointingSelection.AfterTap(Current: A, Picked: A, IsPointing: true, HasTarget: true) == nil)
    }
}
