//
//  OrientationFrame.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/22/26.
//

import Foundation

///One snapshot of the iPhone's position and orientation, sent to the Mac over the local network (see `OrientationSender` on the iPhone
///and `OrientationReceiver` on the Mac). A frame travels as one JSON datagram. Every part but `Timestamp`, `Session` and `Version` is
///optional, so a frame can be sent before the phone has a GPS fix, and fields can be added later without breaking older receivers
///(unknown keys are ignored; missing optional keys decode as `nil`).
nonisolated struct OrientationFrame: Codable, Equatable, Sendable
{
    ///The frame layout this was written with. Raise it when a change would confuse an older receiver.
    nonisolated static let CurrentVersion = 1

    ///The layout version.
    var Version: Int = OrientationFrame.CurrentVersion
    ///Identifies one run of the sender. Frame order is only judged within a session, so a phone whose clock was set back, or that was
    ///restarted, is not ignored.
    var Session: String
    ///When the frame was made, in seconds since 1970. Frames are ordered by this; the receiver ignores a frame no newer than the last
    ///one it accepted.
    var Timestamp: Double
    ///Where the phone is, if it has a fix.
    var Location: LocationReading? = nil
    ///Which way the phone points, if the compass has a reading.
    var Heading: HeadingReading? = nil
    ///How the phone is moving and turned, if device motion is available.
    var Motion: MotionReading? = nil

    ///A GPS fix.
    nonisolated struct LocationReading: Codable, Equatable, Sendable
    {
        ///Degrees north of the equator.
        var Latitude: Double
        ///Degrees east of Greenwich.
        var Longitude: Double
        ///Meters above sea level.
        var Altitude: Double
        ///Radius in meters of the circle the position is within (the phone reports negative when invalid; such fixes are not sent).
        var HorizontalAccuracy: Double
        ///Plus or minus meters for the altitude; negative if the altitude is not valid.
        var VerticalAccuracy: Double
        ///When the fix was taken, in seconds since 1970.
        var FixTimestamp: Double
    }

    ///A compass reading.
    nonisolated struct HeadingReading: Codable, Equatable, Sendable
    {
        ///Degrees clockwise from north that the top of the screen (in the view the phone is in) points at.
        var Degrees: Double
        ///True if `Degrees` is from true north, false if from magnetic north.
        var IsTrueNorth: Bool
        ///Plus or minus degrees; negative means the compass needs calibration.
        var Accuracy: Double
    }

    ///Three numbers along the phone's x, y and z axes.
    nonisolated struct Vector: Codable, Equatable, Sendable
    {
        var X: Double
        var Y: Double
        var Z: Double
    }

    ///Core Motion's device motion, in the phone's own frame.
    nonisolated struct MotionReading: Codable, Equatable, Sendable
    {
        ///Which way gravity pulls, in g.
        var Gravity: Vector
        ///The acceleration the user gives the phone, with gravity taken out, in g.
        var UserAcceleration: Vector
        ///Turning speed about each axis, radians per second.
        var RotationRate: Vector
        ///Attitude as a quaternion (X, Y, Z are the vector part), relative to a frame with Z up and X toward true north when available.
        var Attitude: Quaternion
        ///Rotation about the x axis, radians (positive when the top of the phone tips back).
        var Pitch: Double
        ///Rotation about the y axis, radians.
        var Roll: Double
        ///Rotation about the z axis, radians.
        var Yaw: Double
    }

    ///A rotation.
    nonisolated struct Quaternion: Codable, Equatable, Sendable
    {
        var X: Double
        var Y: Double
        var Z: Double
        var W: Double
    }

    ///The frame as JSON, one datagram's worth. `nil` if encoding fails (a value that is not finite).
    nonisolated func Encoded() -> Data?
    {
        try? JSONEncoder().encode(self)
    }

    ///A frame from a datagram, or `nil` if the bytes are not a frame.
    nonisolated static func Decode(_ Bytes: Data) -> OrientationFrame?
    {
        try? JSONDecoder().decode(OrientationFrame.self, from: Bytes)
    }
}

///Decides which frames to use. A frame whose timestamp is not later than the last accepted frame of its session arrived late (UDP does
///not keep order) or twice, and is ignored.
nonisolated struct OrientationFrameFilter
{
    ///The session of the last accepted frame.
    private(set) var Session: String? = nil
    ///The timestamp of the last accepted frame.
    private(set) var LastTimestamp: Double = -.infinity
    ///How many frames were used.
    private(set) var AcceptedCount = 0
    ///How many frames were thrown away: out of order, repeated, or with a timestamp that is not a number.
    private(set) var IgnoredCount = 0

    ///Judges a frame.
    ///- Returns: true to use it, false to ignore it.
    mutating func Accept(_ Frame: OrientationFrame) -> Bool
    {
        guard Frame.Timestamp.isFinite else
        {
            IgnoredCount += 1
            return false
        }
        //A new session starts afresh, wherever its clock is.
        if Frame.Session != Session
        {
            Session = Frame.Session
            LastTimestamp = -.infinity
        }
        guard Frame.Timestamp > LastTimestamp else
        {
            IgnoredCount += 1
            return false
        }
        LastTimestamp = Frame.Timestamp
        AcceptedCount += 1
        return true
    }
}

///Names shared by the sender and the receiver.
enum OrientationLink
{
    ///The Bonjour service the Mac advertises and the iPhone looks for. It runs over UDP.
    nonisolated static let ServiceType = "_hudview._udp"
    ///Seconds between frames sent: twenty a second.
    nonisolated static let SendInterval = 0.05
    ///Seconds without a frame after which the Mac says the phone has gone quiet.
    nonisolated static let StaleAfter = 3.0
}
