//
//  OrientationReceiver.swift
//  HUDViewMac
//
//  Created by Stuart Rankin on 11/22/26.
//

import Foundation
import Network
import CoreLocation
import Observation

///Receives the frames HUDViewWatch sends from an iPhone.
///
///The Mac advertises the Bonjour service `OrientationLink.ServiceType` and listens for UDP datagrams, each a JSON `OrientationFrame`.
///All networking and decoding runs on a background queue; only a decoded frame is handed to the main actor, so the window never waits
///on the network. If the phone is silent nothing happens at all: the view notices the age of the last frame and says so.
///Frames older than one already used are ignored (see `OrientationFrameFilter`).
@MainActor
@Observable
final class OrientationReceiver
{
    ///What the listener is doing.
    enum State: Equatable
    {
        ///Not yet started.
        case Stopped
        ///Starting, or restarting after a failure.
        case Starting
        ///Advertising and ready for frames.
        case Listening
        ///The listener failed; a restart is scheduled. Carries the reason.
        case Failed(String)
    }

    ///The listener's state.
    private(set) var Status: State = .Stopped
    ///The newest accepted frame; `nil` until one arrives.
    private(set) var Latest: OrientationFrame? = nil
    ///When `Latest` arrived here (by this Mac's clock).
    private(set) var LatestArrival: Date? = nil
    ///How many frames were used.
    private(set) var AcceptedCount = 0
    ///How many frames were ignored for arriving out of order or twice.
    private(set) var IgnoredCount = 0
    ///How many datagrams could not be read as frames.
    private(set) var UnreadableCount = 0

    ///The phone's heading and fix in the form the shared radar views read.
    let Compass = HeadingProvider()

    @ObservationIgnored
    private var Filter = OrientationFrameFilter()
    @ObservationIgnored
    private var Listener: NWListener? = nil
    @ObservationIgnored
    private var Connections: [NWConnection] = []
    @ObservationIgnored
    private var RestartTask: Task<Void, Never>? = nil
    ///The fix timestamp last given to `Compass`, so an unchanged fix does not make the radar redo its work.
    @ObservationIgnored
    private var LastFixTimestamp: Double? = nil
    ///The queue the network works on, off the main thread.
    @ObservationIgnored
    private let Queue = DispatchQueue(label: "HUDViewMac.OrientationReceiver")
    ///The most remote connections kept; older ones are closed. (A phone that restarts appears from a new port.)
    private static let MaxConnections = 4

    ///Starts advertising and listening. Does nothing if already started.
    func Start()
    {
        guard Listener == nil else
        {
            return
        }
        Status = .Starting
        let NewListener: NWListener
        do
        {
            NewListener = try NWListener(using: .udp)
        }
        catch
        {
            Fail(error.localizedDescription)
            return
        }
        NewListener.service = NWListener.Service(name: Host.current().localizedName ?? "Mac", type: OrientationLink.ServiceType)
        NewListener.stateUpdateHandler =
        {
            [weak self] NewState in
            Task
            {
                @MainActor [weak self] in
                self?.ListenerChanged(NewState)
            }
        }
        NewListener.newConnectionHandler =
        {
            [weak self] Connection in
            Task
            {
                @MainActor [weak self] in
                self?.Accept(Connection)
            }
        }
        Listener = NewListener
        NewListener.start(queue: Queue)
    }

    ///Stops listening and closes every connection.
    func Stop()
    {
        RestartTask?.cancel()
        RestartTask = nil
        Listener?.cancel()
        Listener = nil
        Connections.forEach { $0.cancel() }
        Connections.removeAll()
        Status = .Stopped
    }

    ///Seconds since the last frame arrived, or `nil` if none has.
    func Age(At Now: Date = Date()) -> Double?
    {
        LatestArrival.map { Now.timeIntervalSince($0) }
    }

    // MARK: - Listener

    private func ListenerChanged(_ NewState: NWListener.State)
    {
        switch NewState
        {
            case .ready:
                Status = .Listening

            case .failed(let Reason):
                Fail(Reason.localizedDescription)

            case .waiting(let Reason):
                //No network yet. The listener starts by itself when one appears.
                Status = .Failed(Reason.localizedDescription)

            default:
                break
        }
    }

    ///The listener cannot run: show why and try again in a few seconds.
    private func Fail(_ Reason: String)
    {
        Listener?.cancel()
        Listener = nil
        Status = .Failed(Reason)
        RestartTask?.cancel()
        RestartTask = Task
        {
            [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard Task.isCancelled == false, let self else
            {
                return
            }
            self.Start()
        }
    }

    // MARK: - Connections and frames

    ///A phone started sending. Reads its datagrams until the connection ends.
    private func Accept(_ Connection: NWConnection)
    {
        Connections.append(Connection)
        while Connections.count > OrientationReceiver.MaxConnections
        {
            Connections.removeFirst().cancel()
        }
        Connection.stateUpdateHandler =
        {
            [weak self, weak Connection] NewState in
            switch NewState
            {
                case .failed, .cancelled:
                    guard let Closed = Connection else
                    {
                        return
                    }
                    Task
                    {
                        @MainActor [weak self, Closed] in
                        self?.Connections.removeAll { $0 === Closed }
                    }

                default:
                    break
            }
        }
        Connection.start(queue: Queue)
        Receive(From: Connection)
    }

    ///Waits for the next datagram on a connection, hands it on, and waits again. Runs on the network queue.
    nonisolated private func Receive(From Connection: NWConnection)
    {
        Connection.receiveMessage
        {
            [weak self, weak Connection] Bytes, _, _, Error in
            if let Bytes, Bytes.isEmpty == false
            {
                //Decoded here, off the main thread.
                let Frame = OrientationFrame.Decode(Bytes)
                Task
                {
                    @MainActor [weak self] in
                    self?.Use(Frame)
                }
            }
            //An error means the connection is finished; otherwise listen for the next one.
            if Error == nil, let Connection
            {
                self?.Receive(From: Connection)
            }
        }
    }

    ///Takes a decoded frame (or `nil` for bytes that were not one), ignoring it when it is out of order.
    private func Use(_ Frame: OrientationFrame?)
    {
        guard let Frame else
        {
            UnreadableCount += 1
            return
        }
        guard Filter.Accept(Frame) else
        {
            IgnoredCount = Filter.IgnoredCount
            return
        }
        AcceptedCount = Filter.AcceptedCount
        IgnoredCount = Filter.IgnoredCount
        Latest = Frame
        LatestArrival = Date()
        Apply(Frame)
    }

    ///Puts a frame's heading and location into `Compass`, which the radar reads.
    private func Apply(_ Frame: OrientationFrame)
    {
        if let Reading = Frame.Heading
        {
            Compass.Heading = Reading.Degrees
            Compass.IsTrueNorth = Reading.IsTrueNorth
            Compass.Accuracy = Reading.Accuracy
            Compass.LastUpdate = Date()
            Compass.UpdateCount += 1
        }
        if let Fix = Frame.Location, Fix.FixTimestamp != LastFixTimestamp
        {
            LastFixTimestamp = Fix.FixTimestamp
            Compass.Location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: Fix.Latitude, longitude: Fix.Longitude),
                                          altitude: Fix.Altitude, horizontalAccuracy: Fix.HorizontalAccuracy,
                                          verticalAccuracy: Fix.VerticalAccuracy,
                                          timestamp: Date(timeIntervalSince1970: Fix.FixTimestamp))
        }
    }
}
