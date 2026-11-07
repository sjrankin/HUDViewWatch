//
//  MotionProvider.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//  Ported from MotionManager in HUDViewUI.
//

import Foundation
import CoreMotion
import Observation

///Publishes the direction of gravity in the phone's own axes, smoothed, for the camera view's horizon.
@MainActor
@Observable
final class MotionProvider
{
    ///Smoothed gravity. Phone upright in portrait until the first reading (and always in the Simulator, which has no motion).
    private(set) var Pull = Gravity.Upright

    @ObservationIgnored
    private let Manager = CMMotionManager()

    var IsAvailable: Bool
    {
        Manager.isDeviceMotionAvailable
    }

    func Start()
    {
        guard IsAvailable, Manager.isDeviceMotionActive == false else
        {
            return
        }
        //Sixty readings a second; `HUDMath.Smoothed` takes the shake out.
        Manager.deviceMotionUpdateInterval = 1.0 / 60.0
        Manager.startDeviceMotionUpdates(to: .main)
        {
            [weak self] Motion, _ in
            guard let Motion else
            {
                return
            }
            let Reading = Gravity(X: Motion.gravity.x, Y: Motion.gravity.y, Z: Motion.gravity.z)
            //Delivered on the main queue.
            MainActor.assumeIsolated
            {
                if let self
                {
                    self.Pull = HUDMath.Smoothed(Old: self.Pull, New: Reading)
                }
            }
        }
    }

    func Stop()
    {
        Manager.stopDeviceMotionUpdates()
    }
}
