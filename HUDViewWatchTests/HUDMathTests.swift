//
//  HUDMathTests.swift
//  HUDViewWatchTests
//
//  Created by Stuart Rankin on 11/7/26.
//

import CoreGraphics
import CoreLocation
import Foundation
import Testing
@testable import HUDViewWatch

struct HUDMathTests
{
    private let Size = CGSize(width: 400, height: 800)
    private let FieldOfView = 63.0

    private func Item(_ Name: String, Distance: Double, Bearing: Double, Elevation: Double? = nil) -> POIFinder.VisiblePOI
    {
        POIFinder.VisiblePOI(Place: POI(Name: Name, Latitude: 0, Longitude: 0, Kind: .Test, Elevation: Elevation),
                             Distance: Distance, Bearing: Bearing)
    }

    // MARK: Heading

    @Test func FacingHeadingTurnsWithTheInterface()
    {
        #expect(HUDMath.FacingHeading(10, Orientation: .portrait) == 10)
        #expect(HUDMath.FacingHeading(10, Orientation: .landscapeRight) == 100)
        #expect(HUDMath.FacingHeading(10, Orientation: .landscapeLeft) == 280)
        #expect(HUDMath.FacingHeading(350, Orientation: .portraitUpsideDown) == 170)
    }

    @Test func DirectionNamesUseEightPoints()
    {
        #expect(HUDMath.DirectionName(0) == "N")
        #expect(HUDMath.DirectionName(359) == "N")
        #expect(HUDMath.DirectionName(45) == "NE")
        #expect(HUDMath.DirectionName(180) == "S")
        #expect(HUDMath.DirectionName(300) == "NW")
        #expect(HUDMath.DirectionName(nil) == "?")
    }

    @Test func AngleDifferenceTakesTheShortWay()
    {
        #expect(POIFinder.AngleDifference(From: 350, To: 10) == 20)
        #expect(POIFinder.AngleDifference(From: 10, To: 350) == -20)
        #expect(POIFinder.AngleDifference(From: 0, To: 180) == 180)
    }

    // MARK: Motion

    @Test func SmoothingMovesPartWayToTheNewReading()
    {
        let Old = Gravity(X: 0, Y: -1, Z: 0)
        let New = Gravity(X: 1, Y: 0, Z: 0)
        let Result = HUDMath.Smoothed(Old: Old, New: New, Weight: 0.5)
        #expect(Result == Gravity(X: 0.5, Y: -0.5, Z: 0))
        #expect(HUDMath.Smoothed(Old: Old, New: New, Weight: 1) == New)
    }

    // MARK: Horizon

    @Test func UprightPhoneHasALevelHorizonInTheMiddle()
    {
        let Pose = HUDMath.Pose(Pull: .Upright, Size: Size, Orientation: .portrait, FieldOfView: FieldOfView)
        #expect(Pose != nil)
        #expect(abs((Pose?.Center.y ?? 0) - 400) < 0.001)
        #expect(abs(Pose?.Angle ?? 1) < 0.001)
        #expect(abs(Pose?.Pitch ?? 1) < 0.001)
    }

    @Test func APlaceStraightBelowAFlatPhoneIsStillDrawn()
    {
        //Face-up and flat, the back camera looks straight down. A place far below the level (its elevation is hugely negative) is
        //right under it, so it falls in the middle of the view.
        let Below = Item("Below", Distance: 1000, Bearing: 0, Elevation: -10_000_000)
        let Frame = HUDMath.MakeFrame(Items: [Below], DeviceHeading: 0, Pull: Gravity(X: 0, Y: 0, Z: -1), Size: Size,
                                      Orientation: .portrait, FieldOfView: FieldOfView, IsFrontCamera: false, Locked: false,
                                      UserHeight: 0, Limit: 20)
        #expect(Frame.Pose != nil)
        #expect(Frame.Placements.count == 1)
        if let Point = Frame.Placements.first?.Point
        {
            #expect(abs(Double(Point.x) - 200) < 5)
            #expect(abs(Double(Point.y) - 400) < 5)
        }
    }

    @Test func AFlatPhoneStillHasAPose()
    {
        let Flat = Gravity(X: 0, Y: 0, Z: -1)
        let Pose = HUDMath.Pose(Pull: Flat, Size: Size, Orientation: .portrait, FieldOfView: FieldOfView)
        //Flat: still a pose, with the camera looking straight down (or up) and no roll.
        #expect(Pose != nil)
        #expect(Pose.map { abs(abs($0.Pitch) - .pi / 2) < 0.001 } == true)
        #expect(Pose?.Angle == 0)
    }

    @Test func LockingHoldsTheHorizonInTheMiddleWhateverTheTilt()
    {
        let Tilted = Gravity(X: 0.5, Y: -0.7, Z: -0.5)
        let Pose = HUDMath.Pose(Pull: Tilted, Size: Size, Orientation: .portrait, FieldOfView: FieldOfView, Locked: true)
        #expect(Pose == HorizonPose(Center: CGPoint(x: 200, y: 400), Angle: 0, Pitch: 0))
    }

    @Test func TippingTheCameraUpMovesTheHorizonDown()
    {
        //Z is gravity along the camera axis: looking up gives a negative component for the back camera.
        let Up = Gravity(X: 0, Y: -0.9, Z: 0.3)
        let Pose = HUDMath.Pose(Pull: Up, Size: Size, Orientation: .portrait, FieldOfView: FieldOfView)
        #expect((Pose?.Pitch ?? 0) > 0)
    }

    @Test func LongerFocalLengthForANarrowerFieldOfView()
    {
        let Wide = HUDMath.FocalPoints(Size: Size, Orientation: .portrait, FieldOfView: 80)
        let Narrow = HUDMath.FocalPoints(Size: Size, Orientation: .portrait, FieldOfView: 40)
        #expect(Narrow > Wide)
    }

    // MARK: Projection

    @Test func ElevationDropsWithTheCurveOfTheEarth()
    {
        //10 km away at your own height: below the level by 10000² / (2 R) = 7.85 m, about 0.045 degrees.
        let Angle = HUDMath.ElevationAngle(PointHeight: 0, UserHeight: 0, Distance: 10_000)
        #expect(Angle < 0)
        #expect(abs(Angle + 0.045) < 0.002)
        //A tall mountain 100 km away still shows above you if it is high enough.
        #expect(HUDMath.ElevationAngle(PointHeight: 4000, UserHeight: 0, Distance: 100_000) > 0)
    }

    @Test func StraightAheadAtTheHorizonProjectsToTheMiddle()
    {
        let Pose = HorizonPose(Center: CGPoint(x: 200, y: 400), Angle: 0, Pitch: 0)
        let Point = HUDMath.Project(Relative: 0, Elevation: 0, Pose: Pose, Focal: 600, Middle: CGPoint(x: 200, y: 400))
        #expect(Point != nil)
        #expect(abs((Point?.x ?? 0) - 200) < 0.001)
        #expect(abs((Point?.y ?? 0) - 400) < 0.001)
    }

    @Test func ThePointOppositeTheEarthIsStraightDown()
    {
        let Opposite = Double.pi * HUDMath.EarthRadius
        #expect(abs(HUDMath.ElevationAngle(PointHeight: 0, UserHeight: 0, Distance: Opposite) + 90) < 0.01)
    }

    @Test func FarPlacesAreBelowTheLevelByHalfTheArc()
    {
        //8,000 km away: half of 8000 / 6371 radians is about 35.97 degrees.
        let Angle = HUDMath.ElevationAngle(PointHeight: 0, UserHeight: 0, Distance: 8_000_000)
        #expect(abs(Angle + 35.97) < 0.05)
    }

    @Test func TheHUDLimitsNoDistance()
    {
        #expect(HUDView.MaxDistance > Double.pi * HUDMath.EarthRadius)
    }

    @Test func AFarSidePlaceIsDrawnWhenTheCameraLooksDownAtIt()
    {
        let Far = Item("Far side", Distance: 14_660_000, Bearing: 0)
        let Down = HUDMath.ElevationAngle(PointHeight: 0, UserHeight: 0, Distance: 14_660_000)
        #expect(Down < -60)
        //Tip the camera down by exactly that much: the place falls in the middle of the view.
        let Pitch = Down * .pi / 180
        let Frame = HUDMath.MakeFrame(Items: [Far], DeviceHeading: 0, Pull: Gravity(X: 0, Y: -cos(Pitch), Z: sin(Pitch)), Size: Size,
                                      Orientation: .portrait, FieldOfView: FieldOfView, IsFrontCamera: false, Locked: false,
                                      UserHeight: 0, Limit: 20)
        #expect(Frame.Placements.count == 1)
        if let Point = Frame.Placements.first?.Point
        {
            #expect(abs(Double(Point.x) - 200) < 3)
            #expect(abs(Double(Point.y) - 400) < 3)
        }
    }

    @Test func AWiderLensShowsPlacesFartherToTheSide()
    {
        //A place 45° to the right: outside the ordinary lens's picture, but inside the ultra-wide lens's.
        let Place = Item("Side", Distance: 1000, Bearing: 45)
        func Shown(FieldOfView Wide: Double) -> Int
        {
            HUDMath.MakeFrame(Items: [Place], DeviceHeading: 0, Pull: .Upright, Size: Size, Orientation: .portrait,
                              FieldOfView: Wide, IsFrontCamera: false, Locked: true, UserHeight: 0, Limit: 20).Placements.count
        }
        #expect(Shown(FieldOfView: 63) == 0)
        #expect(Shown(FieldOfView: 120) == 1)
    }

    @Test func ToTheRightProjectsToTheRightAndAboveProjectsHigher()
    {
        let Pose = HorizonPose(Center: CGPoint(x: 200, y: 400), Angle: 0, Pitch: 0)
        let Middle = CGPoint(x: 200, y: 400)
        let Right = HUDMath.Project(Relative: 10, Elevation: 0, Pose: Pose, Focal: 600, Middle: Middle)
        let Above = HUDMath.Project(Relative: 0, Elevation: 10, Pose: Pose, Focal: 600, Middle: Middle)
        #expect((Right?.x ?? 0) > 200)
        #expect((Above?.y ?? 1000) < 400)
    }

    @Test func BehindTheCameraProjectsNowhere()
    {
        let Pose = HorizonPose(Center: CGPoint(x: 200, y: 400), Angle: 0, Pitch: 0)
        #expect(HUDMath.Project(Relative: 180, Elevation: 0, Pose: Pose, Focal: 600, Middle: CGPoint(x: 200, y: 400)) == nil)
    }

    @Test func OnlyThePlacesInViewAreKeptNearestFirstUpToTheLimit()
    {
        let Pose = HorizonPose(Center: CGPoint(x: 200, y: 400), Angle: 0, Pitch: 0)
        let Items = [Item("Far", Distance: 9000, Bearing: 0), Item("Near", Distance: 1000, Bearing: 2),
                     Item("Behind", Distance: 500, Bearing: 180), Item("Mid", Distance: 5000, Bearing: 350)]
        let Focal = HUDMath.FocalPoints(Size: Size, Orientation: .portrait, FieldOfView: FieldOfView)
        let Placed = HUDMath.Place(Items, Facing: 0, UserHeight: 0, Pose: Pose, Focal: Focal, Size: Size, OnHorizon: false, Limit: 2)
        #expect(Placed.map { $0.Item.Place.Name } == ["Near", "Mid"])
    }

    @Test func LockedHorizonPutsEveryPlaceOnTheLine()
    {
        let Pose = HorizonPose(Center: CGPoint(x: 200, y: 400), Angle: 0, Pitch: 0)
        let Focal = HUDMath.FocalPoints(Size: Size, Orientation: .portrait, FieldOfView: FieldOfView)
        let Items = [Item("High", Distance: 20_000, Bearing: 0, Elevation: 3000)]
        let Free = HUDMath.Place(Items, Facing: 0, UserHeight: 0, Pose: Pose, Focal: Focal, Size: Size, OnHorizon: false, Limit: 5)
        let Locked = HUDMath.Place(Items, Facing: 0, UserHeight: 0, Pose: Pose, Focal: Focal, Size: Size, OnHorizon: true, Limit: 5)
        #expect((Free.first?.Point.y ?? 400) < 400)
        #expect(abs((Locked.first?.Point.y ?? 0) - 400) < 0.001)
    }

    @Test func TheSelfieCameraShowsNoPlaces()
    {
        let Items = [Item("Ahead", Distance: 1000, Bearing: 0)]
        let Back = HUDMath.MakeFrame(Items: Items, DeviceHeading: 0, Pull: .Upright, Size: Size, Orientation: .portrait,
                                     FieldOfView: FieldOfView, IsFrontCamera: false, Locked: false, UserHeight: 0, Limit: 10)
        let Front = HUDMath.MakeFrame(Items: Items, DeviceHeading: 0, Pull: .Upright, Size: Size, Orientation: .portrait,
                                      FieldOfView: FieldOfView, IsFrontCamera: true, Locked: false, UserHeight: 0, Limit: 10)
        #expect(Back.Placements.count == 1)
        #expect(Front.Placements.isEmpty)
        #expect(Front.Pose != nil)
    }

    // MARK: Pointing arrow

    private func Arrow(For Place: POIFinder.VisiblePOI, Heading: Double = 0, Locked: Bool = true) -> HUDMath.GuideArrow?
    {
        let Area = CGRect(x: 30, y: 110, width: 340, height: 580)
        return HUDMath.MakeFrame(Items: [Place], DeviceHeading: Heading, Pull: .Upright, Size: Size, Orientation: .portrait,
                                 FieldOfView: FieldOfView, IsFrontCamera: false, Locked: Locked, UserHeight: 0, Limit: 20,
                                 GuideTarget: Place.id, GuideArea: Area).Arrow
    }

    @Test func ThePointingModeShowsAnArrowAndNoMarkers()
    {
        let Place = Item("A", Distance: 1000, Bearing: 0)
        let Frame = HUDMath.MakeFrame(Items: [Place], DeviceHeading: 0, Pull: .Upright, Size: Size, Orientation: .portrait,
                                      FieldOfView: FieldOfView, IsFrontCamera: false, Locked: true, UserHeight: 0, Limit: 20,
                                      GuideTarget: Place.id)
        #expect(Frame.Placements.isEmpty)
        #expect(Frame.Arrow != nil)
    }

    @Test func AnUnknownTargetLeavesTheMarkers()
    {
        let Place = Item("A", Distance: 1000, Bearing: 0)
        let Frame = HUDMath.MakeFrame(Items: [Place], DeviceHeading: 0, Pull: .Upright, Size: Size, Orientation: .portrait,
                                      FieldOfView: FieldOfView, IsFrontCamera: false, Locked: true, UserHeight: 0, Limit: 20,
                                      GuideTarget: UUID())
        #expect(Frame.Placements.count == 1)
        #expect(Frame.Arrow == nil)
    }

    @Test func InViewTheTipIsWhereTheMarkerWouldBe()
    {
        let Place = Item("A", Distance: 1000, Bearing: 10)
        let Marker = HUDMath.MakeFrame(Items: [Place], DeviceHeading: 0, Pull: .Upright, Size: Size, Orientation: .portrait,
                                       FieldOfView: FieldOfView, IsFrontCamera: false, Locked: true, UserHeight: 0, Limit: 20)
            .Placements.first?.Point
        let Found = Arrow(For: Place, Locked: true)
        #expect(Found?.IsOffScreen == false)
        //The circle is where the marker would be, and the tip stops one clearance short of it.
        #expect(Found?.Spot == Marker)
        if let Found, let Spot = Found.Spot
        {
            let Gap = hypot(Double(Spot.x - Found.Tip.x), Double(Spot.y - Found.Tip.y))
            #expect(abs(Gap - 12.0) < 0.001)
        }
    }

    @Test func ANearlyCenteredTargetIsPointedDownAt()
    {
        let Found = Arrow(For: Item("A", Distance: 1000, Bearing: 0))
        #expect(Found?.IsOffScreen == false)
        #expect(Found?.Direction == CGPoint(x: 0, y: 1))
    }

    @Test func ATargetToTheRightOutOfViewGivesARedArrowOnTheRightEdge()
    {
        let Found = Arrow(For: Item("A", Distance: 1000, Bearing: 60))
        #expect(Found?.IsOffScreen == true)
        #expect(Found?.Spot == nil)
        #expect(Found.map { abs(Double($0.Tip.x) - 370) < 0.001 } == true)
        #expect(Found.map { $0.Direction.x > 0.9 } == true)
    }

    @Test func ATargetBehindTheCameraTurnsYouTheShortWay()
    {
        let Right = Arrow(For: Item("A", Distance: 1000, Bearing: 170))
        let Left = Arrow(For: Item("B", Distance: 1000, Bearing: 190))
        #expect(Right?.IsOffScreen == true)
        #expect(Right.map { $0.Direction.x > 0 } == true)
        #expect(Left.map { $0.Direction.x < 0 } == true)
    }

    @Test func TheArrowCarriesTheNameAndDistance()
    {
        let Found = Arrow(For: Item("Fremont", Distance: 1234, Bearing: 10))
        #expect(Found?.Name == "Fremont")
        #expect(Found?.Distance == 1234)
    }

    @Test func TheLabelSitsBehindTheTailAndStaysInBounds()
    {
        let Bounds = CGRect(x: 30, y: 110, width: 340, height: 580)
        let Label = CGSize(width: 100, height: 40)
        //Pointing right from the middle: the label is to the left of the tail.
        let Level = HUDMath.GuideArrow(Tip: CGPoint(x: 300, y: 400), Spot: nil, Kind: .Test, Direction: CGPoint(x: 1, y: 0), IsOffScreen: false,
                                       Name: "A", Distance: 1)
        let Left = HUDGuideArrowView.LabelCenter(Arrow: Level, LabelSize: Label, Bounds: Bounds)
        #expect(Left.y == 400)
        #expect(Left.x + 50 < 300 - HUDGuideArrowView.Length)
        //Pointing right at the edge, far to the left: it would run off, so it is held at the bounds.
        let Edge = HUDMath.GuideArrow(Tip: CGPoint(x: 120, y: 400), Spot: nil, Kind: .Test, Direction: CGPoint(x: 1, y: 0), IsOffScreen: true,
                                      Name: "A", Distance: 1)
        let Held = HUDGuideArrowView.LabelCenter(Arrow: Edge, LabelSize: Label, Bounds: Bounds)
        #expect(Held.x == Bounds.minX + 50)
    }

    @Test func TheEdgePointStaysInsideTheArea()
    {
        let Area = CGRect(x: 30, y: 110, width: 340, height: 580)
        let Tip = HUDMath.EdgePoint(From: CGPoint(x: 200, y: 400), Direction: CGPoint(x: 0, y: -1), In: Area)
        #expect(Tip == CGPoint(x: 200, y: 110))
        #expect(Area.insetBy(dx: -0.001, dy: -0.001).contains(Tip))
    }

    @Test func FarPlacesFade()
    {
        #expect(HUDMath.Opacity(Distance: 1000) == 1.0)
        #expect(HUDMath.Opacity(Distance: 10_000) == 0.9)
        #expect(HUDMath.Opacity(Distance: 30_000) == 0.8)
        #expect(HUDMath.Opacity(Distance: 500_000) == 0.7)
    }
}

struct DistanceUnitTests
{
    @Test func MetricUsesMetersThenKilometers()
    {
        #expect(DistanceUnit.Metric.Format(Meters: 850) == "850 m")
        #expect(DistanceUnit.Metric.Format(Meters: 2500) == "2.5 km")
        #expect(DistanceUnit.Metric.Format(Meters: 231_000) == "231 km")
    }

    @Test func ImperialUsesFeetThenMiles()
    {
        #expect(DistanceUnit.Imperial.Format(Meters: 100) == "328 ft")
        #expect(DistanceUnit.Imperial.Format(Meters: 3218.688) == "2.0 mi")
        #expect(DistanceUnit.Imperial.Format(Meters: 160_934.4) == "100 mi")
    }

    @Test func TheDefaultFormatterIsMetric()
    {
        #expect(DistanceFormat.Short(Meters: 2500) == "2.5 km")
        #expect(DistanceFormat.Short(Meters: 1609.344, Unit: .Imperial) == "1.0 mi")
    }
}

struct POIFinderExtrasTests
{
    @Test func TypeFilterKeepsOnlyTheChosenKinds()
    {
        let Here = CLLocation(latitude: 38, longitude: -121)
        let City = POI(Name: "Town", Latitude: 38.01, Longitude: -121, Kind: .City)
        let Lake = POI(Name: "Pond", Latitude: 38.02, Longitude: -121, Kind: .Lake)
        let Only = POIFinder.POIs(In: [City, Lake], Near: Here, MaxDistance: 100_000, TypeFilter: [.Lake])
        #expect(Only.map { $0.Place.Name } == ["Pond"])
        #expect(POIFinder.POIs(In: [City, Lake], Near: Here, MaxDistance: 100_000, TypeFilter: []).count == 2)
        #expect(POIFinder.POIs(In: [City, Lake], Near: Here, MaxDistance: 100_000, TypeFilter: nil).count == 2)
    }

    @Test func FieldOfViewFilterKeepsThePlacesInFront()
    {
        let Ahead = POIFinder.VisiblePOI(Place: POI(Name: "Ahead", Latitude: 0, Longitude: 0, Kind: .Test), Distance: 1, Bearing: 20)
        let Side = POIFinder.VisiblePOI(Place: POI(Name: "Side", Latitude: 0, Longitude: 0, Kind: .Test), Distance: 1, Bearing: 90)
        let Seen = POIFinder.InFieldOfView([Ahead, Side], Facing: 0, FieldOfView: 60)
        #expect(Seen.map { $0.Place.Name } == ["Ahead"])
    }
}

@MainActor
struct HUDSettingsTests
{
    private func MakeSettings() -> (RadarSettings, UserDefaults)
    {
        let Defaults = UserDefaults(suiteName: "HUDViewWatchTests-\(UUID().uuidString)")!
        return (RadarSettings(Defaults: Defaults), Defaults)
    }

    @Test func UnitDefaultsToMetricAndIsRemembered()
    {
        let (Settings, Defaults) = MakeSettings()
        #expect(Settings.Unit == .Metric)
        Settings.Unit = .Imperial
        #expect(RadarSettings(Defaults: Defaults).Unit == .Imperial)
    }

    @Test func MarkerLimitIsClampedAndRemembered()
    {
        let (Settings, Defaults) = MakeSettings()
        #expect(Settings.HUDMarkerLimit == 10)
        Settings.HUDMarkerLimit = 500
        #expect(Settings.HUDMarkerLimit == 30)
        Settings.HUDMarkerLimit = 1
        #expect(Settings.HUDMarkerLimit == 3)
        Settings.HUDMarkerLimit = 12
        #expect(RadarSettings(Defaults: Defaults).HUDMarkerLimit == 12)
    }

    @Test func HorizonLockIsOffByDefaultAndIsRemembered()
    {
        let (Settings, Defaults) = MakeSettings()
        #expect(Settings.HorizonLocked == false)
        Settings.HorizonLocked = true
        #expect(RadarSettings(Defaults: Defaults).HorizonLocked)
    }

    @Test func PlacesKeepTheirDescriptionAndOldFilesStillLoad() throws
    {
        let Place = POI(Name: "Work", Latitude: 1, Longitude: 2, Kind: .Test, Description: "RWC Office")
        let Back = try POIStore.Decode(try POIStore.Encode([Place]))
        #expect(Back.first?.Description == "RWC Office")
        let Old = "[{\"id\":\"\(UUID().uuidString)\",\"Name\":\"Old\",\"Latitude\":1,\"Longitude\":2,\"Kind\":\"Park\"}]"
        #expect(try POIStore.Decode(Data(Old.utf8)).first?.Description == nil)
    }

    @Test func DraftsCarryTheDescription()
    {
        let Draft = PlaceDraft(Editing: POI(Name: "Work", Latitude: 1, Longitude: 2, Kind: .Test, Description: "RWC Office"))
        #expect(Draft.Note == "RWC Office")
        Draft.Note = "   "
        #expect(Draft.Make()?.Description == nil)
        Draft.Note = " Office "
        #expect(Draft.Make()?.Description == "Office")
    }

    @Test func TheMergedBuiltInPlacesIncludeHUDViewUIsExtras()
    {
        let Names = Set(NorthernCaliforniaData.AllPOIs.map(\.Name))
        #expect(Names.isSuperset(of: ["Danville", "Redwood City", "Washington DC"]))
        #expect(NorthernCaliforniaData.AllPOIs.first { $0.Name == "Old House" }?.Description == "Shingle Springs")
    }
}
