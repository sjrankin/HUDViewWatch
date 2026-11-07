//
//  HeadingProvider.swift
//  HUDViewWatch Watch App
//
//  Created by Stuart Rankin on 10/26/26.
//

import CoreLocation
import Combine

///Publishes the direction the watch is facing, in degrees clockwise from true north.
///True north needs location authorization; until it is granted (or when the heading is
///invalid) the magnetic heading is used so the display still works.
final class HeadingProvider: NSObject, ObservableObject, CLLocationManagerDelegate
{
    ///Degrees clockwise from true north (0...360) the top of the watch is pointing at.
    @Published var Heading: Double = 0.0
    ///True if Heading is relative to true north, false if it fell back to magnetic north.
    @Published var IsTrueNorth: Bool = false

    ///The most recent location fix, nil until the first one arrives.
    @Published var Location: CLLocation? = nil
    ///Heading accuracy in degrees; negative means Core Location says the compass needs calibration.
    @Published var Accuracy: Double = -1.0
    ///When the last heading update arrived.
    @Published var LastUpdate: Date? = nil
    ///Number of heading updates received since Start.
    @Published var UpdateCount: Int = 0
    ///Text of the last Core Location error, if any.
    @Published var LastError: String? = nil
    @Published var Authorization: CLAuthorizationStatus = .notDetermined

    private let Manager = CLLocationManager()

    override init()
    {
        super.init()
        Manager.delegate = self
        Manager.headingFilter = 1
        //GPS-grade fixes (onboard, or from the paired iPhone when the watch lacks a fix), delivered
        //each time the user moves 10 m so the radar tracks walking.
        Manager.desiredAccuracy = kCLLocationAccuracyBest
        Manager.distanceFilter = 10
    }

    func Start()
    {
        Manager.requestWhenInUseAuthorization()
        //Location updates are what let Core Location compute the declination for true north.
        Manager.startUpdatingLocation()
        Manager.startUpdatingHeading()
    }

    func Stop()
    {
        Manager.stopUpdatingHeading()
        Manager.stopUpdatingLocation()
    }

    func locationManager(_ Manager: CLLocationManager, didUpdateHeading NewHeading: CLHeading)
    {
        //Readings are still used when accuracy is negative (calibration wanted) so the dial keeps moving;
        //the status line shows the accuracy instead.
        Accuracy = NewHeading.headingAccuracy
        LastUpdate = Date()
        UpdateCount += 1
        //A negative trueHeading means no true north yet.
        if NewHeading.trueHeading >= 0
        {
            Heading = NewHeading.trueHeading
            IsTrueNorth = true
        }
        else if NewHeading.magneticHeading >= 0
        {
            Heading = NewHeading.magneticHeading
            IsTrueNorth = false
        }
    }

    func locationManager(_ Manager: CLLocationManager, didUpdateLocations Locations: [CLLocation])
    {
        //Skip cached fixes (old timestamp) and invalid ones (negative accuracy); the first delivery is often stale.
        let Fresh = Locations.filter { $0.horizontalAccuracy >= 0 && $0.timestamp.timeIntervalSinceNow > -30 }
        if let Latest = Fresh.last
        {
            Location = Latest
        }
    }

    func locationManager(_ Manager: CLLocationManager, didFailWithError Error: Error)
    {
        LastError = Error.localizedDescription
    }

    func locationManagerDidChangeAuthorization(_ Manager: CLLocationManager)
    {
        Authorization = Manager.authorizationStatus
        switch Manager.authorizationStatus
        {
            case .authorizedWhenInUse, .authorizedAlways:
                Manager.startUpdatingLocation()
                Manager.startUpdatingHeading()

            default:
                break
        }
    }
}
