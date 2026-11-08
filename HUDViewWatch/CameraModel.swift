//
//  CameraModel.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//  Ported from ViewController_Camera in HUDViewUI.
//

import Foundation
import AVFoundation
import Observation

///Owns the capture session. Starting and stopping a session blocks, so it is done off the main actor; the class is marked
///unchecked-Sendable because it is only ever used one call at a time.
final class CaptureSession: @unchecked Sendable
{
    let Session = AVCaptureSession()
    private var CurrentInput: AVCaptureDeviceInput?

    ///The camera that was chosen: its field of view in degrees along the long side of its picture, and whether it is the ultra-wide one.
    struct Choice: Sendable
    {
        var FieldOfView: Double
        var IsWide: Bool
    }

    ///Whether this phone has an ultra-wide back camera (the 0.5× one).
    static var HasUltraWide: Bool
    {
        AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
    }

    ///Chooses the camera, or `nil` when there is no such camera (the Simulator has none).
    ///- Parameter Wide: True for the back camera's ultra-wide lens. The ordinary lens is used when there is none, or for the selfie camera.
    func Use(_ Position: AVCaptureDevice.Position, Wide: Bool = false) -> Choice?
    {
        let WantsWide = Wide && Position == .back
        let Ultra = WantsWide ? AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) : nil
        guard let Device = Ultra ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: Position),
              let NewInput = try? AVCaptureDeviceInput(device: Device) else
        {
            return nil
        }
        Session.beginConfiguration()
        if let Old = CurrentInput
        {
            Session.removeInput(Old)
        }
        if Session.canAddInput(NewInput)
        {
            Session.addInput(NewInput)
            CurrentInput = NewInput
        }
        else if let Old = CurrentInput
        {
            Session.addInput(Old)
        }
        Session.commitConfiguration()
        //The field of view is the lens's own: the ultra-wide one is about twice as wide, which is what spreads the places out.
        return Choice(FieldOfView: Double(Device.activeFormat.videoFieldOfView), IsWide: Ultra != nil)
    }

    func Run()
    {
        if Session.isRunning == false
        {
            Session.startRunning()
        }
    }

    func Halt()
    {
        if Session.isRunning
        {
            Session.stopRunning()
        }
    }
}

///The camera behind the HUD: permission, which camera is in use and its field of view (the horizon's distance from the middle of the
///picture depends on it).
@MainActor
@Observable
final class CameraModel
{
    enum State
    {
        ///Permission not asked yet.
        case Idle
        case Running
        ///The user said no to the camera.
        case Denied
        ///No camera (the Simulator).
        case Unavailable
    }

    private(set) var Status = State.Idle
    ///The camera's field of view in degrees along the long side of its picture. Phones' main cameras are near 63°.
    private(set) var FieldOfView = 63.0
    private(set) var IsFront = false
    ///True while the ultra-wide (0.5×) lens is in use.
    private(set) var IsWide = false
    ///True if the user wants the wide view whenever the back camera is in use (it is not used for the selfie camera).
    private var PrefersWide = false
    ///True if this phone has an ultra-wide camera to offer.
    let CanUseWide = CaptureSession.HasUltraWide

    @ObservationIgnored
    let Capture = CaptureSession()

    ///Asks for permission if needed and starts the picture.
    func Start() async
    {
        guard await AVCaptureDevice.requestAccess(for: .video) else
        {
            Status = .Denied
            return
        }
        await Choose(IsFront ? .front : .back)
    }

    func Stop()
    {
        let Running = Capture
        Task.detached
        {
            Running.Halt()
        }
    }

    ///Switches between the back camera and the selfie camera.
    func SwitchCamera() async
    {
        await Choose(IsFront ? .back : .front)
    }

    ///Switches the back camera between its ordinary lens (1×) and its ultra-wide one (0.5×).
    func ToggleWide() async
    {
        guard CanUseWide, IsFront == false else
        {
            return
        }
        PrefersWide.toggle()
        await Choose(.back)
    }

    private func Choose(_ Position: AVCaptureDevice.Position) async
    {
        let Running = Capture
        let Wide = PrefersWide
        let Found = await Task.detached
        {
            () -> CaptureSession.Choice? in
            let Result = Running.Use(Position, Wide: Wide)
            if Result != nil
            {
                Running.Run()
            }
            return Result
        }.value
        guard let Found else
        {
            Status = .Unavailable
            return
        }
        FieldOfView = Found.FieldOfView
        IsWide = Found.IsWide
        IsFront = Position == .front
        Status = .Running
    }
}
