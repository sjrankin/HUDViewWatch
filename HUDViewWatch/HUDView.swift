//
//  HUDView.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//  Replaces ViewController in HUDViewUI: the camera with a horizon line, a compass bar and the places drawn over it.
//

import SwiftUI
import CoreLocation

///The camera view. Places slide in and out of view as the phone turns, each one placed through the same pinhole camera as the horizon
///line, so a place at your own height sits just below the line and the Earth's curve drops far ones lower.
struct HUDView: View
{
    @Environment(POIStore.self) private var Store
    @Environment(RadarSettings.self) private var Settings
    @Environment(PlaceSelection.self) private var Selection
    @ObservedObject var Compass: HeadingProvider
    @State private var Camera = CameraModel()
    @State private var Motion = MotionProvider()
    @State private var Smoother = HeadingSmoother()
    ///The size of the camera area in points, and which way the interface is turned.
    @State private var Size = CGSize.zero
    @State private var Orientation = ScreenOrientation.portrait
    ///Every visible place with its distance and bearing from the last fix.
    @State private var Nearby: [POIFinder.VisiblePOI] = []
    @State private var ShowingLocation = false

    ///Every place on Earth is in range for the camera: the horizon, not a distance, decides what can be seen.
    static let MaxDistance = 12_742_000.0

    ///What to draw right now, for the given (smoothed) device heading.
    func MakeFrame(Heading: Double) -> HUDMath.Frame
    {
        HUDMath.MakeFrame(Items: Nearby, DeviceHeading: Heading, Pull: Motion.Pull, Size: Size,
                          Orientation: Orientation, FieldOfView: Camera.FieldOfView, IsFrontCamera: Camera.IsFront,
                          Locked: Settings.HorizonLocked, UserHeight: Compass.Location?.altitude ?? 0.0,
                          Limit: Settings.HUDMarkerLimit)
    }

    func Refresh()
    {
        guard let Here = Compass.Location else
        {
            Nearby = []
            return
        }
        Nearby = POIFinder.POIs(In: Store.Visible, Near: Here, MaxDistance: HUDView.MaxDistance)
    }

    var body: some View
    {
        //Redrawn every screen frame so the smoothed heading glides between compass readings.
        TimelineView(.animation)
        {
            Timeline in
            let Drawing = MakeFrame(Heading: Smoother.Value(Target: Compass.Heading, At: Timeline.date))
            ZStack
            {
            Color.black
            if Camera.Status == .Running
            {
                CameraPreview(Session: Camera.Capture.Session, Orientation: Orientation, IsFrontCamera: Camera.IsFront)
            }
            HUDOverlay(Frame: Drawing, Unit: Settings.Unit, SelectedID: Selection.SelectedID, Area: Size,
                       OnSelect: { Selection.Toggle($0) }, OnClear: { Selection.SelectedID = nil })
            VStack
            {
                CompassBarView(Heading: Drawing.Facing)
                    .frame(height: 56)
                    .background(.black.opacity(0.6))
                Text("\(HUDMath.DirectionName(Drawing.Facing)) \(HeadingFormat.Degrees(Drawing.Facing))")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(.yellow, in: .rect(cornerRadius: 10))
                if let Message = StatusMessage
                {
                    Text(Message)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.6), in: .rect(cornerRadius: 12))
                }
                Spacer()
                if ShowingLocation
                {
                    LocationToast(Heading: Compass.Location == nil && Compass.UpdateCount == 0 ? nil : Compass.Heading,
                                  Location: Compass.Location, Unit: Settings.Unit)
                    {
                        ShowingLocation = false
                    }
                }
                HUDControls(IsFront: Camera.IsFront, IsLocked: Settings.HorizonLocked, IsShowingLocation: ShowingLocation,
                            OnSwitchCamera: { Task { await Camera.SwitchCamera() } },
                            OnToggleLock: { Settings.HorizonLocked.toggle() },
                            OnToggleLocation: { ShowingLocation.toggle() })
                    .padding(.bottom)
            }
            }
        }
        .clipped()
        .onGeometryChange(for: CGSize.self)
        {
            $0.size
        }
        action:
        {
            Size = $0
            Orientation = ScreenOrientation.Current
        }
        .task(id: Size)
        {
            //The window's orientation can still be the old one at the instant the size changes, so look again once the turn has settled.
            try? await Task.sleep(for: .milliseconds(350))
            Orientation = ScreenOrientation.Current
        }
        .task
        {
            await Camera.Start()
        }
        .onAppear
        {
            Compass.Start()
            Motion.Start()
            Refresh()
        }
        .onDisappear
        {
            Motion.Stop()
            Camera.Stop()
        }
        .onChange(of: Compass.Location)
        {
            Refresh()
        }
        .onChange(of: Store.Visible)
        {
            Refresh()
        }
    }

    ///Why the picture or the horizon is missing, if it is.
    var StatusMessage: String?
    {
        switch Camera.Status
        {
            case .Denied:
                return "Camera access is off. Turn it on in Settings to see the picture behind the places."

            case .Unavailable:
                return "No camera is available. The places are drawn over a black background."

            default:
                break
        }
        if MakeFrame(Heading: Compass.Heading).Pose == nil
        {
            return "Hold the phone upright to see the places."
        }
        return nil
    }
}

///The horizon line and the places over the camera.
struct HUDOverlay: View
{
    let Frame: HUDMath.Frame
    let Unit: DistanceUnit
    let SelectedID: UUID?
    ///The size of the camera area.
    let Area: CGSize
    let OnSelect: (UUID) -> Void
    ///Called when the user taps where there is no place.
    let OnClear: () -> Void

    var body: some View
    {
        ZStack
        {
            //Behind the places, so a tap that misses them clears the selection.
            Button(action: OnClear)
            {
                Color.clear
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear selection")
            //Places are layered by negative distance, so this has to be lower than any of them.
            .zIndex(-.greatestFiniteMagnitude)
            Canvas
            {
                Context, Size in
                guard let Pose = Frame.Pose else
                {
                    return
                }
                //A line longer than the view can ever show, so its ends are never seen.
                let Reach = hypot(Size.width, Size.height)
                var Line = Path()
                Line.move(to: CGPoint(x: -Reach, y: 0))
                Line.addLine(to: CGPoint(x: Reach, y: 0))
                Context.translateBy(x: Pose.Center.x, y: Pose.Center.y)
                Context.rotate(by: .radians(Pose.Angle))
                Context.stroke(Line, with: .color(.red.opacity(0.85)), lineWidth: 4)
            }
            .allowsHitTesting(false)
            ForEach(Frame.Placements)
            {
                Entry in
                HUDPlacedMarker(Entry: Entry, Unit: Unit, IsSelected: Entry.id == SelectedID, Area: Area, OnSelect: OnSelect)
            }
        }
    }
}

///The buttons along the bottom of the camera view.
struct HUDControls: View
{
    let IsFront: Bool
    let IsLocked: Bool
    let IsShowingLocation: Bool
    let OnSwitchCamera: () -> Void
    let OnToggleLock: () -> Void
    let OnToggleLocation: () -> Void

    var body: some View
    {
        HStack(spacing: 24)
        {
            Button(IsFront ? "Use Back Camera" : "Use Selfie Camera", systemImage: "arrow.triangle.2.circlepath.camera",
                   action: OnSwitchCamera)
            Button(IsLocked ? "Unlock Horizon" : "Lock Horizon", systemImage: IsLocked ? "lock.fill" : "lock.open",
                   action: OnToggleLock)
            Button(IsShowingLocation ? "Hide Location" : "Show Location", systemImage: IsShowingLocation ? "location.fill" : "location",
                   action: OnToggleLocation)
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: .capsule)
    }
}
