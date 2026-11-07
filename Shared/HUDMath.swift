//
//  HUDMath.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//  Ported from MainOverlay, POIOverlayView, LocationManager and MotionManager in HUDViewUI, without any UIKit or CoreMotion types so
//  it can be tested.
//

import Foundation
import CoreGraphics

///Which way the interface is turned. The phone's own axes never change, but which of them points to the right and to the top of the
///screen does.
enum ScreenOrientation: Equatable, Sendable
{
    case portrait
    case portraitUpsideDown
    ///Home indicator on the right: the phone's top points left.
    case landscapeRight
    ///Home indicator on the left: the phone's top points right.
    case landscapeLeft

    var IsLandscape: Bool
    {
        self == .landscapeLeft || self == .landscapeRight
    }
}

///Gravity in the phone's own axes, in g (the same axes and units as CoreMotion's `gravity`).
struct Gravity: Equatable, Sendable
{
    var X: Double
    var Y: Double
    var Z: Double

    ///Phone upright in portrait.
    static let Upright = Gravity(X: 0.0, Y: -1.0, Z: 0.0)
}

///Where the horizon is on screen: the middle of the line, how far it is rolled and the camera's pitch.
struct HorizonPose: Equatable, Sendable
{
    ///The middle of the line, in points.
    var Center: CGPoint
    ///Clockwise roll on screen, in radians.
    var Angle: Double
    ///How far the camera looks above the level, in radians.
    var Pitch: Double
}

///The camera, horizon and projection math of the camera view.
enum HUDMath
{
    static let EarthRadius = 6_371_000.0

    // MARK: Heading

    ///The compass heading is the way the top of the phone points. The way the phone faces (the camera's direction) is a quarter turn
    ///from that when the interface is in landscape.
    static func FacingHeading(_ DeviceHeading: Double, Orientation: ScreenOrientation) -> Double
    {
        let Offset: Double
        switch Orientation
        {
            case .landscapeRight:
                Offset = 90.0

            case .landscapeLeft:
                Offset = -90.0

            case .portraitUpsideDown:
                Offset = 180.0

            case .portrait:
                Offset = 0.0
        }
        return (DeviceHeading + Offset + 360.0).truncatingRemainder(dividingBy: 360.0)
    }

    ///The sixteen compass point names, keyed by their bearing in degrees.
    static let CompassPoints: [(Bearing: Double, Name: String)] =
    [(0.0, "N"), (22.5, "NNE"), (45.0, "NE"), (67.5, "ENE"), (90.0, "E"), (112.5, "ESE"), (135.0, "SE"), (157.5, "SSE"),
     (180.0, "S"), (202.5, "SSW"), (225.0, "SW"), (247.5, "WSW"), (270.0, "W"), (292.5, "WNW"), (315.0, "NW"), (337.5, "NNW")]

    ///The eight-point name for a heading, e.g. "NE", or "?" for none.
    static func DirectionName(_ Heading: Double?) -> String
    {
        guard let Heading, Heading.isFinite else
        {
            return "?"
        }
        let Names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let Wrapped = (Heading.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        return Names[Int(((Wrapped + 22.5) / 45.0).rounded(.down)) % 8]
    }

    // MARK: Motion

    ///How much of each new gravity reading is taken in (the rest is the old value): 1 is no smoothing. Reduces the shakiness of a
    ///hand-held phone.
    static let SmoothingWeight = 0.35

    ///A low-pass filter on the gravity vector, so the horizon does not tremble with the hand.
    static func Smoothed(Old: Gravity, New: Gravity, Weight: Double = SmoothingWeight) -> Gravity
    {
        let Keep = 1.0 - Weight
        return Gravity(X: Old.X * Keep + New.X * Weight, Y: Old.Y * Keep + New.Y * Weight, Z: Old.Z * Keep + New.Z * Weight)
    }

    ///Gravity's components along the screen's right and up directions. (For the interface in landscape, the screen's "up" is along the
    ///phone's own X axis, one way or the other, and its "right" is along Y.)
    static func ScreenComponents(_ Pull: Gravity, Orientation: ScreenOrientation) -> (Right: Double, Up: Double)
    {
        switch Orientation
        {
            case .landscapeRight:
                return (-Pull.Y, Pull.X)

            case .landscapeLeft:
                return (Pull.Y, -Pull.X)

            case .portraitUpsideDown:
                return (-Pull.X, -Pull.Y)

            case .portrait:
                return (Pull.X, Pull.Y)
        }
    }

    // MARK: Camera and horizon

    ///The camera's focal length in points. The video fills the view and is 3:4 in portrait (4:3 in landscape), so its long side, in
    ///points, is what the field of view spans.
    ///- Parameter FieldOfView: The camera's field of view in degrees along the long side of its picture.
    static func FocalPoints(Size: CGSize, Orientation: ScreenOrientation, FieldOfView: Double) -> Double
    {
        let Width = Double(Size.width)
        let Height = Double(Size.height)
        let LongSide = Orientation.IsLandscape ? max(Width, Height * 4.0 / 3.0) : max(Height, Width * 4.0 / 3.0)
        return LongSide / (2.0 * tan(FieldOfView * .pi / 180.0 / 2.0))
    }

    ///Where the horizon is for the phone's current gravity, or `nil` when the phone is nearly flat (the horizon is out of sight).
    ///
    ///The camera's elevation above the horizon is the arcsine of gravity's component along the camera's axis, and the horizon is
    ///that far (in focal lengths) from the middle of the picture, on the side gravity points to on the screen.
    ///- Parameter Locked: True to hold the horizon level in the middle of the view.
    ///- Parameter IsFrontCamera: The selfie camera looks out of the screen's side, so its elevation has the opposite sign.
    static func Pose(Pull: Gravity, Size: CGSize, Orientation: ScreenOrientation, FieldOfView: Double,
                     IsFrontCamera: Bool = false, Locked: Bool = false) -> HorizonPose?
    {
        guard Size.width > 0, Size.height > 0 else
        {
            return nil
        }
        let Middle = CGPoint(x: Size.width / 2.0, y: Size.height / 2.0)
        if Locked
        {
            return HorizonPose(Center: Middle, Angle: 0.0, Pitch: 0.0)
        }
        let Screen = ScreenComponents(Pull, Orientation: Orientation)
        //Gravity's direction on the screen (screen y points down), as a unit vector.
        let OnScreen = CGPoint(x: Screen.Right, y: -Screen.Up)
        let Length = hypot(OnScreen.x, OnScreen.y)
        guard Length > 0.15 else
        {
            return nil
        }
        let Direction = CGPoint(x: OnScreen.x / Length, y: OnScreen.y / Length)
        let Along = IsFrontCamera ? -Pull.Z : Pull.Z
        let Elevation = asin(max(-1.0, min(1.0, Along)))
        let Focal = FocalPoints(Size: Size, Orientation: Orientation, FieldOfView: FieldOfView)
        //tan() grows without limit looking straight up or down: keep the line a finite distance away.
        let Offset = max(-3000.0, min(3000.0, Focal * tan(Elevation)))
        let Center = CGPoint(x: Middle.x + Direction.x * Offset, y: Middle.y + Direction.y * Offset)
        return HorizonPose(Center: Center, Angle: atan2(-Screen.Right, -Screen.Up), Pitch: Elevation)
    }

    // MARK: Points of interest

    ///The angle in degrees above the level (positive) or below it (negative) at which a point `Distance` meters away is seen. The
    ///Earth's surface curves away, so a point at your own height ends up below the level by `Distance² / (2R)`.
    static func ElevationAngle(PointHeight: Double, UserHeight: Double, Distance: Double) -> Double
    {
        let Drop = (Distance * Distance) / (2.0 * EarthRadius)
        return atan2(PointHeight - UserHeight - Drop, Distance) * 180.0 / .pi
    }

    ///Where a direction falls in the view, or `nil` if it is behind the camera.
    ///- Parameter Relative: Degrees the direction is to the right of the way the phone faces.
    ///- Parameter Elevation: Degrees above the level horizon.
    ///- Parameter Pose: The horizon's center, roll and the camera's pitch.
    ///- Parameter Focal: The camera's focal length in points.
    ///- Parameter Middle: The middle of the view, which the horizon rolls about.
    static func Project(Relative: Double, Elevation: Double, Pose: HorizonPose, Focal: Double, Middle: CGPoint) -> CGPoint?
    {
        let Azimuth = Relative * .pi / 180.0
        let Rise = Elevation * .pi / 180.0
        let DX = sin(Azimuth) * cos(Rise)
        let DY = cos(Azimuth) * cos(Rise)
        let DZ = sin(Rise)
        //The camera looks `Pitch` above the level: its forward axis is (0, cos, sin) and its up axis is (0, -sin, cos).
        let Forward = DY * cos(Pose.Pitch) + DZ * sin(Pose.Pitch)
        guard Forward > 0.05 else
        {
            return nil
        }
        let Up = -DY * sin(Pose.Pitch) + DZ * cos(Pose.Pitch)
        let SX = Focal * DX / Forward
        let SY = -Focal * Up / Forward
        //The horizon is rolled about the middle of the view, and everything rolls with it.
        return CGPoint(x: Double(Middle.x) + SX * cos(Pose.Angle) - SY * sin(Pose.Angle),
                       y: Double(Middle.y) + SX * sin(Pose.Angle) + SY * cos(Pose.Angle))
    }

    ///A place placed on the camera view.
    struct Placement: Identifiable, Equatable
    {
        let Item: POIFinder.VisiblePOI
        ///Where the place's dot is, in points.
        let Point: CGPoint
        var id: UUID
        {
            Item.id
        }

        static func == (Left: Placement, Right: Placement) -> Bool
        {
            Left.id == Right.id && Left.Point == Right.Point
        }
    }

    ///Where each place falls on the camera view, nearest `Limit` only (nearest first), dropping the ones outside the view (with a
    ///margin) or behind the camera.
    ///- Parameter Facing: The way the camera faces, in degrees from north.
    ///- Parameter UserHeight: The user's height above sea level in meters.
    ///- Parameter OnHorizon: True to put every place on the horizon line (the horizon is locked), whatever its height or distance.
    static func Place(_ Items: [POIFinder.VisiblePOI], Facing: Double, UserHeight: Double, Pose: HorizonPose, Focal: Double,
                      Size: CGSize, OnHorizon: Bool, Limit: Int, Margin: Double = 60.0) -> [Placement]
    {
        let Middle = CGPoint(x: Size.width / 2.0, y: Size.height / 2.0)
        let Allowed = CGRect(origin: .zero, size: Size).insetBy(dx: -Margin, dy: -Margin)
        var Shown: [Placement] = []
        for Item in Items
        {
            let Relative = POIFinder.AngleDifference(From: Facing, To: Item.Bearing)
            let Elevation = OnHorizon ? 0.0
                : ElevationAngle(PointHeight: Item.Place.Elevation ?? 0.0, UserHeight: UserHeight, Distance: Item.Distance)
            if let Point = Project(Relative: Relative, Elevation: Elevation, Pose: Pose, Focal: Focal, Middle: Middle),
               Allowed.contains(Point)
            {
                Shown.append(Placement(Item: Item, Point: Point))
            }
        }
        return Array(Shown.sorted { $0.Item.Distance < $1.Item.Distance }.prefix(max(Limit, 0)))
    }

    ///How opaque a place's label is: farther places fade.
    static func Opacity(Distance: Double) -> Double
    {
        Distance < 5000 ? 1.0 : (Distance < 20_000 ? 0.9 : (Distance < 50_000 ? 0.8 : 0.7))
    }

    ///Everything the camera view draws for one moment.
    struct Frame: Equatable
    {
        ///The horizon, or `nil` when the phone is nearly flat (nothing is drawn then).
        var Pose: HorizonPose?
        ///The way the camera faces, in degrees from north.
        var Facing: Double
        ///The places on the view, nearest first.
        var Placements: [Placement]
    }

    ///Works out the horizon and the place markers for the current heading, tilt and view.
    ///- Parameter Items: Places with their distance and bearing from the user.
    ///- Parameter DeviceHeading: The way the top of the phone points, in degrees from north.
    ///- Parameter UserHeight: The user's height above sea level in meters.
    ///- Parameter Limit: The most markers to place.
    static func MakeFrame(Items: [POIFinder.VisiblePOI], DeviceHeading: Double, Pull: Gravity, Size: CGSize,
                          Orientation: ScreenOrientation, FieldOfView: Double, IsFrontCamera: Bool, Locked: Bool,
                          UserHeight: Double, Limit: Int) -> Frame
    {
        let Facing = FacingHeading(DeviceHeading, Orientation: Orientation)
        guard let Pose = Pose(Pull: Pull, Size: Size, Orientation: Orientation, FieldOfView: FieldOfView,
                              IsFrontCamera: IsFrontCamera, Locked: Locked) else
        {
            return Frame(Pose: nil, Facing: Facing, Placements: [])
        }
        //The selfie camera looks the other way, so no places are shown for it.
        if IsFrontCamera
        {
            return Frame(Pose: Pose, Facing: Facing, Placements: [])
        }
        let Focal = FocalPoints(Size: Size, Orientation: Orientation, FieldOfView: FieldOfView)
        let Placements = Place(Items, Facing: Facing, UserHeight: UserHeight, Pose: Pose, Focal: Focal, Size: Size,
                               OnHorizon: Locked, Limit: Limit)
        return Frame(Pose: Pose, Facing: Facing, Placements: Placements)
    }
}
