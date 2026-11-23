//
//  OrientationFrameTests.swift
//  HUDViewWatchTests
//
//  Created by Stuart Rankin on 11/22/26.
//

import Testing
import Foundation
@testable import HUDViewWatch

struct OrientationFrameTests
{
    private func Frame(_ Time: Double, Session: String = "A") -> OrientationFrame
    {
        OrientationFrame(Session: Session, Timestamp: Time)
    }

    @Test func RoundTripKeepsEveryField()
    {
        var Original = Frame(1_000.5)
        Original.Location = .init(Latitude: 37.5, Longitude: -122.25, Altitude: 12.5, HorizontalAccuracy: 5, VerticalAccuracy: 3, FixTimestamp: 999)
        Original.Heading = .init(Degrees: 271.5, IsTrueNorth: true, Accuracy: 10)
        Original.Motion = .init(Gravity: .init(X: 0, Y: -1, Z: 0), UserAcceleration: .init(X: 0.1, Y: 0, Z: 0),
                                RotationRate: .init(X: 0, Y: 0.2, Z: 0), Attitude: .init(X: 0, Y: 0, Z: 0, W: 1),
                                Pitch: 0.1, Roll: 0.2, Yaw: 0.3)
        let Bytes = Original.Encoded()
        #expect(Bytes != nil)
        #expect(OrientationFrame.Decode(Bytes ?? Data()) == Original)
    }

    @Test func MissingOptionalPartsAndUnknownKeysDecode()
    {
        let Text = #"{"Version":1,"Session":"S","Timestamp":5,"SomethingNew":[1,2,3]}"#
        let Decoded = OrientationFrame.Decode(Data(Text.utf8))
        #expect(Decoded?.Timestamp == 5)
        #expect(Decoded?.Location == nil)
    }

    @Test func GarbageIsNotAFrame()
    {
        #expect(OrientationFrame.Decode(Data("hello".utf8)) == nil)
        #expect(OrientationFrame.Decode(Data()) == nil)
    }

    @Test func LateAndRepeatedFramesAreIgnored()
    {
        var Filter = OrientationFrameFilter()
        let Accepted1 = Filter.Accept(Frame(10))
        #expect(Accepted1)
        let Accepted2 = Filter.Accept(Frame(12))
        #expect(Accepted2)
        let Accepted3 = Filter.Accept(Frame(11))
        #expect(Accepted3 == false)
        let Accepted4 = Filter.Accept(Frame(12))
        #expect(Accepted4 == false)
        let Accepted5 = Filter.Accept(Frame(13))
        #expect(Accepted5)
        #expect(Filter.AcceptedCount == 3)
        #expect(Filter.IgnoredCount == 2)
    }

    @Test func NewSessionStartsAfresh()
    {
        var Filter = OrientationFrameFilter()
        let Accepted6 = Filter.Accept(Frame(100, Session: "A"))
        #expect(Accepted6)
        //The phone restarted with its clock set back.
        let Accepted7 = Filter.Accept(Frame(50, Session: "B"))
        #expect(Accepted7)
        let Accepted8 = Filter.Accept(Frame(49, Session: "B"))
        #expect(Accepted8 == false)
    }

    @Test func NonFiniteTimestampIsIgnored()
    {
        var Filter = OrientationFrameFilter()
        let Accepted9 = Filter.Accept(Frame(.nan))
        #expect(Accepted9 == false)
        let Accepted10 = Filter.Accept(Frame(.infinity))
        #expect(Accepted10 == false)
    }
}
