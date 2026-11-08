//
//  HeadingSmoother.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//

import Foundation

///Eases a compass heading toward the latest reading, once per screen frame, so the camera view glides instead of stepping each
///time Core Location delivers a new heading. Plain (not observed) because the view asks for a value every frame anyway.
@MainActor
final class HeadingSmoother
{
    ///How long, in seconds, the shown heading takes to cover most of the way to a new reading. Smaller is snappier.
    static let TimeConstant = 0.12

    private var Shown: Double?
    private var LastTime: Date?

    ///The heading to draw at `Time`, given the newest reading.
    ///- Parameters:
    ///  - Target: The latest heading in degrees clockwise from north.
    ///  - Time: The time of the frame being drawn.
    func Value(Target: Double, At Time: Date) -> Double
    {
        guard let Current = Shown, let Last = LastTime else
        {
            Shown = Target
            LastTime = Time
            return Target
        }
        let Elapsed = Time.timeIntervalSince(Last)
        //Same frame asked twice, or the clock went backwards: nothing to do.
        guard Elapsed > 0.0 else
        {
            return Current
        }
        LastTime = Time
        let Next = HeadingSmoother.Eased(From: Current, To: Target, Elapsed: Elapsed)
        Shown = Next
        return Next
    }

    ///Moves `From` toward `To` along the short way round the circle.
    static func Eased(From: Double, To: Double, Elapsed: Double) -> Double
    {
        var Difference = (To - From).truncatingRemainder(dividingBy: 360.0)
        if Difference > 180.0
        {
            Difference -= 360.0
        }
        else if Difference < -180.0
        {
            Difference += 360.0
        }
        let Share = 1.0 - exp(-Elapsed / TimeConstant)
        var Result = (From + Difference * Share).truncatingRemainder(dividingBy: 360.0)
        if Result < 0.0
        {
            Result += 360.0
        }
        return Result
    }
}
