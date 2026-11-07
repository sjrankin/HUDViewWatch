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

    ///Chooses the camera. Returns its field of view in degrees along the long side of its picture, or `nil` when there is no such camera
    ///(the Simulator has none).
    func Use(_ Position: AVCaptureDevice.Position) -> Double?
    {
        guard let Device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: Position),
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
        return Double(Device.activeFormat.videoFieldOfView)
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

    private func Choose(_ Position: AVCaptureDevice.Position) async
    {
        let Running = Capture
        let Found = await Task.detached
        {
            () -> Double? in
            let Result = Running.Use(Position)
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
        FieldOfView = Found
        IsFront = Position == .front
        Status = .Running
    }
}
