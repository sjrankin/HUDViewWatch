//
//  CameraPreview.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//  Ported from CameraView and ViewController_Camera in HUDViewUI.
//

import SwiftUI
import UIKit
import AVFoundation

///The live camera picture. SwiftUI has no camera view of its own, so this wraps the capture preview layer; it is the only UIKit in the
///camera screen.
struct CameraPreview: UIViewRepresentable
{
    let Session: AVCaptureSession
    let Orientation: ScreenOrientation
    let IsFrontCamera: Bool

    ///A view whose layer is the preview layer.
    final class PreviewView: UIView
    {
        override class var layerClass: AnyClass
        {
            AVCaptureVideoPreviewLayer.self
        }

        var PreviewLayer: AVCaptureVideoPreviewLayer
        {
            layer as! AVCaptureVideoPreviewLayer
        }
    }

    func makeUIView(context: Context) -> PreviewView
    {
        let View = PreviewView()
        View.PreviewLayer.session = Session
        View.PreviewLayer.videoGravity = .resizeAspectFill
        return View
    }

    func updateUIView(_ View: PreviewView, context: Context)
    {
        let Angle = CameraPreview.RotationAngle(Orientation: Orientation, IsFrontCamera: IsFrontCamera)
        if let Connection = View.PreviewLayer.connection, Connection.isVideoRotationAngleSupported(Angle)
        {
            Connection.videoRotationAngle = Angle
        }
    }

    ///The angle the picture has to be turned with the interface, or the camera shows sideways in landscape. The selfie camera's
    ///sensor sits turned half a circle the other way round from the back camera's, so its two landscape angles are swapped.
    static func RotationAngle(Orientation: ScreenOrientation, IsFrontCamera: Bool) -> CGFloat
    {
        switch Orientation
        {
            case .landscapeRight:
                return IsFrontCamera ? 180 : 0

            case .landscapeLeft:
                return IsFrontCamera ? 0 : 180

            case .portraitUpsideDown:
                return 270

            case .portrait:
                return 90
        }
    }
}

extension ScreenOrientation
{
    ///The way the interface of the app's window is turned right now (portrait if there is no window yet).
    @MainActor
    static var Current: ScreenOrientation
    {
        let Scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        switch Scene?.effectiveGeometry.interfaceOrientation
        {
            case .landscapeRight:
                return .landscapeRight

            case .landscapeLeft:
                return .landscapeLeft

            case .portraitUpsideDown:
                return .portraitUpsideDown

            default:
                return .portrait
        }
    }
}
