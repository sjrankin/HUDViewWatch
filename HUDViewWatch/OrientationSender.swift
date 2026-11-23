//
//  OrientationSender.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/22/26.
//

import Foundation
import Network
import CoreLocation
import CoreMotion
import Observation

///Sends the phone's location, altitude, heading and device motion to HUDViewMac on the same network, twenty times a second, while the
///"Send to Mac" setting is on.
///
///The Mac advertises a Bonjour service (`OrientationLink.ServiceType`). This looks for it, and sends each frame as one UDP datagram.
///Nothing here can fail loudly: with no Mac around the phone simply keeps looking, frames are dropped rather than queued, and every
///error ends in the "Searching" state and another try a little later.
@MainActor
@Observable
final class OrientationSender
{
    ///What the sender is doing, for the Settings screen.
    enum State: Equatable
    {
        ///Switched off.
        case Off
        ///On, and no Mac has been found.
        case Searching
        ///A Mac was found and is being reached.
        case Connecting(String)
        ///Frames are going to the named Mac.
        case Sending(String)

        ///A line for the Settings screen.
        var Description: String
        {
            switch self
            {
                case .Off:
                    return "Off."
                case .Searching:
                    return "Looking for HUDViewMac on this network…"
                case .Connecting(let Name):
                    return "Connecting to \(Name)…"
                case .Sending(let Name):
                    return "Sending to \(Name)."
            }
        }
    }

    ///What the sender is doing now.
    private(set) var Status: State = .Off
    ///How many frames have been sent since the sender was last switched on.
    private(set) var SentCount = 0

    @ObservationIgnored
    private let Compass = HeadingProvider()
    @ObservationIgnored
    private let Motion = CMMotionManager()
    ///The latest device motion; the frame loop reads it.
    @ObservationIgnored
    private var LatestMotion: OrientationFrame.MotionReading? = nil
    @ObservationIgnored
    private var Browser: NWBrowser? = nil
    @ObservationIgnored
    private var Connection: NWConnection? = nil
    @ObservationIgnored
    private var Loop: Task<Void, Never>? = nil
    @ObservationIgnored
    private var RetryTask: Task<Void, Never>? = nil
    ///True between `Start` and `Stop`.
    @ObservationIgnored
    private var IsRunning = false
    ///Seconds to wait before looking again after a failure; doubles up to `MaxRetryDelay`.
    @ObservationIgnored
    private var RetryDelay = 1.0
    @ObservationIgnored
    private let MaxRetryDelay = 10.0
    ///A new value for each run, so the Mac does not compare this run's frames with an earlier run's.
    @ObservationIgnored
    private var Session = UUID().uuidString

    ///Turns sending on or off.
    func SetEnabled(_ Enabled: Bool)
    {
        if Enabled
        {
            Start()
        }
        else
        {
            Stop()
        }
    }

    ///Starts the sensors, looks for the Mac and begins the frame loop. Does nothing if already running.
    func Start()
    {
        guard IsRunning == false else
        {
            return
        }
        IsRunning = true
        Session = UUID().uuidString
        SentCount = 0
        Status = .Searching
        Compass.Start()
        StartMotion()
        StartBrowsing()
        Loop = Task
        {
            [weak self] in
            //A Task that is cancelled ends the loop; sleeping throws then.
            while Task.isCancelled == false
            {
                self?.SendFrame()
                try? await Task.sleep(for: .seconds(OrientationLink.SendInterval))
            }
        }
    }

    ///Stops everything: the loop, the network and the sensors.
    func Stop()
    {
        IsRunning = false
        Loop?.cancel()
        Loop = nil
        RetryTask?.cancel()
        RetryTask = nil
        Browser?.cancel()
        Browser = nil
        DropConnection()
        Motion.stopDeviceMotionUpdates()
        LatestMotion = nil
        Compass.Stop()
        Status = .Off
    }

    // MARK: - Sensors

    ///Starts device motion, kept in `LatestMotion`.
    private func StartMotion()
    {
        guard Motion.isDeviceMotionAvailable, Motion.isDeviceMotionActive == false else
        {
            return
        }
        Motion.deviceMotionUpdateInterval = OrientationLink.SendInterval
        //True north when the phone can tell; otherwise the attitude has no fixed heading.
        let Frames = CMMotionManager.availableAttitudeReferenceFrames()
        let Reference: CMAttitudeReferenceFrame = Frames.contains(.xTrueNorthZVertical) ? .xTrueNorthZVertical : .xArbitraryZVertical
        Motion.startDeviceMotionUpdates(using: Reference, to: .main)
        {
            [weak self] Reading, _ in
            guard let Reading else
            {
                return
            }
            let Converted = OrientationSender.Convert(Reading)
            MainActor.assumeIsolated
            {
                self?.LatestMotion = Converted
            }
        }
    }

    ///Core Motion's reading as the part of a frame.
    nonisolated private static func Convert(_ Reading: CMDeviceMotion) -> OrientationFrame.MotionReading
    {
        let Q = Reading.attitude.quaternion
        return OrientationFrame.MotionReading(
            Gravity: .init(X: Reading.gravity.x, Y: Reading.gravity.y, Z: Reading.gravity.z),
            UserAcceleration: .init(X: Reading.userAcceleration.x, Y: Reading.userAcceleration.y, Z: Reading.userAcceleration.z),
            RotationRate: .init(X: Reading.rotationRate.x, Y: Reading.rotationRate.y, Z: Reading.rotationRate.z),
            Attitude: .init(X: Q.x, Y: Q.y, Z: Q.z, W: Q.w),
            Pitch: Reading.attitude.pitch, Roll: Reading.attitude.roll, Yaw: Reading.attitude.yaw)
    }

    // MARK: - Frames

    ///The frame for this moment.
    private func MakeFrame() -> OrientationFrame
    {
        var Frame = OrientationFrame(Session: Session, Timestamp: Date().timeIntervalSince1970)
        if let Fix = Compass.Location, Fix.horizontalAccuracy >= 0
        {
            Frame.Location = .init(Latitude: Fix.coordinate.latitude, Longitude: Fix.coordinate.longitude, Altitude: Fix.altitude,
                                   HorizontalAccuracy: Fix.horizontalAccuracy, VerticalAccuracy: Fix.verticalAccuracy,
                                   FixTimestamp: Fix.timestamp.timeIntervalSince1970)
        }
        //No heading until the compass has delivered one.
        if Compass.LastUpdate != nil
        {
            Frame.Heading = .init(Degrees: Compass.Heading, IsTrueNorth: Compass.IsTrueNorth, Accuracy: Compass.Accuracy)
        }
        Frame.Motion = LatestMotion
        return Frame
    }

    ///Sends one frame if a Mac is connected; otherwise does nothing (frames are never queued).
    private func SendFrame()
    {
        guard let Connection, Connection.state == .ready, let Bytes = MakeFrame().Encoded() else
        {
            return
        }
        Connection.send(content: Bytes, completion: .contentProcessed
        {
            [weak self] Error in
            //A UDP send fails when the network has gone away; start looking again.
            if Error != nil
            {
                Task
                {
                    @MainActor [weak self] in
                    self?.LostConnection()
                }
            }
        })
        SentCount += 1
    }

    // MARK: - Finding the Mac

    ///Looks for the Mac's Bonjour service.
    private func StartBrowsing()
    {
        Browser?.cancel()
        let NewBrowser = NWBrowser(for: .bonjour(type: OrientationLink.ServiceType, domain: nil), using: .udp)
        NewBrowser.browseResultsChangedHandler =
        {
            [weak self] Results, _ in
            let Found = Results.first
            Task
            {
                @MainActor [weak self] in
                self?.FoundMacs(Found)
            }
        }
        NewBrowser.stateUpdateHandler =
        {
            [weak self] NewState in
            switch NewState
            {
                case .failed, .waiting:
                    //No network, or the local network permission was refused. Try again later.
                    Task
                    {
                        @MainActor [weak self] in
                        self?.LostConnection()
                    }

                default:
                    break
            }
        }
        Browser = NewBrowser
        NewBrowser.start(queue: .main)
    }

    ///The Bonjour results changed. With none, the Mac is gone (or never was): drop the connection and keep searching. Otherwise connect to
    ///the first Mac, unless already connected to it.
    private func FoundMacs(_ Result: NWBrowser.Result?)
    {
        guard IsRunning else
        {
            return
        }
        guard let Result else
        {
            DropConnection()
            Status = .Searching
            return
        }
        if let Connection, Connection.endpoint == Result.endpoint, Connection.state != .cancelled
        {
            return
        }
        Connect(To: Result.endpoint)
    }

    ///Opens the UDP "connection" to the Mac.
    private func Connect(To Endpoint: NWEndpoint)
    {
        DropConnection()
        let Name = OrientationSender.Name(of: Endpoint)
        Status = .Connecting(Name)
        let NewConnection = NWConnection(to: Endpoint, using: .udp)
        NewConnection.stateUpdateHandler =
        {
            [weak self, weak NewConnection] NewState in
            guard let Current = NewConnection else
            {
                return
            }
            Task
            {
                @MainActor [weak self, Current] in
                guard let self, self.Connection === Current else
                {
                    return
                }
                switch NewState
                {
                    case .ready:
                        self.RetryDelay = 1.0
                        self.Status = .Sending(Name)

                    case .failed, .cancelled:
                        self.LostConnection()

                    case .waiting:
                        self.Status = .Connecting(Name)

                    default:
                        break
                }
            }
        }
        Connection = NewConnection
        NewConnection.start(queue: .main)
    }

    ///The Mac's name from its Bonjour endpoint.
    nonisolated private static func Name(of Endpoint: NWEndpoint) -> String
    {
        if case .service(let Name, _, _, _) = Endpoint
        {
            return Name
        }
        return "the Mac"
    }

    ///Closes the connection, if there is one.
    private func DropConnection()
    {
        Connection?.stateUpdateHandler = nil
        Connection?.cancel()
        Connection = nil
    }

    ///The connection or the browser failed: go back to searching, and search again after a delay that grows to ten seconds.
    private func LostConnection()
    {
        guard IsRunning else
        {
            return
        }
        DropConnection()
        Status = .Searching
        guard RetryTask == nil else
        {
            return
        }
        let Delay = RetryDelay
        RetryDelay = min(RetryDelay * 2, MaxRetryDelay)
        RetryTask = Task
        {
            [weak self] in
            try? await Task.sleep(for: .seconds(Delay))
            guard Task.isCancelled == false, let self else
            {
                return
            }
            self.RetryTask = nil
            if self.IsRunning
            {
                self.StartBrowsing()
            }
        }
    }
}
