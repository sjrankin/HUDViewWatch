//
//  HeadingSmootherTests.swift
//  HUDViewWatchTests
//
//  Created by Stuart Rankin on 11/7/26.
//

import Testing
@testable import HUDViewWatch

@MainActor
struct HeadingSmootherTests
{
    @Test func MovesTowardTarget()
    {
        let Next = HeadingSmoother.Eased(From: 10.0, To: 50.0, Elapsed: 1.0 / 60.0)
        #expect(Next > 10.0 && Next < 50.0)
    }

    @Test func TakesShortWayAcrossNorth()
    {
        let Next = HeadingSmoother.Eased(From: 350.0, To: 10.0, Elapsed: 1.0 / 60.0)
        #expect(Next > 350.0 || Next < 10.0)
    }

    @Test func SettlesOnTarget()
    {
        let Next = HeadingSmoother.Eased(From: 100.0, To: 200.0, Elapsed: 10.0)
        #expect(abs(Next - 200.0) < 0.01)
    }
}
