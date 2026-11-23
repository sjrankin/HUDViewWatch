//
//  HeadingProvider.swift
//  HUDViewMac
//
//  Created by Stuart Rankin on 11/22/26.
//

import Foundation
import CoreLocation
import Combine

///The Mac's stand-in for the iPhone and watch `HeadingProvider`, with the same names so the shared radar views work unchanged. A Mac has no
///compass, so nothing here reads a sensor: `OrientationReceiver` sets the values from the frames the iPhone sends. `Start` and `Stop`
///(called by the radar when it appears and disappears) do nothing.
final class HeadingProvider: NSObject, ObservableObject
{
    ///Degrees clockwise from north the phone points at.
    @Published var Heading: Double = 0.0
    ///True if `Heading` is from true north.
    @Published var IsTrueNorth: Bool = false
    ///The phone's latest fix; `nil` until a frame with one arrives.
    @Published var Location: CLLocation? = nil
    ///Plus or minus degrees; negative means the phone's compass needs calibration.
    @Published var Accuracy: Double = -1.0
    ///When the last heading arrived.
    @Published var LastUpdate: Date? = nil
    ///How many headings have arrived.
    @Published var UpdateCount: Int = 0
    ///Not used on the Mac.
    @Published var LastError: String? = nil
    ///Not used on the Mac; reported as authorized so the shared status line reads sensibly.
    @Published var Authorization: CLAuthorizationStatus = .authorizedAlways

    func Start()
    {
    }

    func Stop()
    {
    }
}
