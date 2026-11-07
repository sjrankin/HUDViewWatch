//
//  WatchLink.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/4/26.
//

import Foundation
import Observation
import WatchConnectivity

///Carries the user's own places from the iPhone to the watch with WatchConnectivity's application context, which always delivers
///the latest list (even if the watch app is not running when it is sent). The iPhone sends; the watch only receives.
@MainActor
@Observable
final class WatchLink: NSObject, WCSessionDelegate
{
    ///One line for the user about the state of the link, e.g. "Sent 3 places to the watch".
    private(set) var Status = "Connecting…"

    ///True for a moment after a send, so the button can show that the tap registered.
    private(set) var IsSending = false

    ///Counts sends; the Places screen uses it to give haptic feedback on every tap, even when the status text is unchanged.
    private(set) var SendCount = 0

    @ObservationIgnored
    private let Store: POIStore
    @ObservationIgnored
    private let Settings: RadarSettings

    nonisolated static let ContextKey = "CustomPOIs"
    nonisolated static let RangeKey = "MaxRangeKilometers"
    nonisolated static let DeletedKey = "DeletedBuiltIns"
    nonisolated static let HiddenKey = "HiddenBuiltIns"
    nonisolated static let UnitKey = "DistanceUnit"
    nonisolated static let StampKey = "SentAt"
    nonisolated static let CountKey = "Count"

    private static func Clock(_ Date: Date = Date()) -> String
    {
        Date.formatted(date: .omitted, time: .standard)
    }

    init(Store: POIStore, Settings: RadarSettings)
    {
        self.Store = Store
        self.Settings = Settings
        super.init()
        guard WCSession.isSupported() else
        {
            Status = "Watch connection is not available."
            return
        }
        let Session = WCSession.default
        Session.delegate = self
        Session.activate()
    }

    // MARK: Sending (iPhone)

    #if os(iOS)
    ///Sends every custom place to the watch, replacing the watch's list. Every call gives visible and haptic feedback, and the
    ///status always carries the time, so two taps in a row never look the same.
    func Send()
    {
        SendCount += 1
        guard WCSession.isSupported() else
        {
            return
        }
        let Session = WCSession.default
        guard Session.activationState == .activated else
        {
            Status = "Connecting… (\(WatchLink.Clock()))"
            return
        }
        guard Session.isPaired else
        {
            Status = "No Apple Watch is paired."
            return
        }
        guard Session.isWatchAppInstalled else
        {
            Status = "The watch app is not installed on the watch."
            return
        }
        let Count = Store.Custom.count
        let Noun = Count == 1 ? "place" : "places"
        do
        {
            let Raw = try POIStore.Encode(Store.Custom)
            //The time makes every send different; WatchConnectivity may drop a context identical to the last one.
            let Payload: [String: Any] = [WatchLink.ContextKey: Raw,
                                           WatchLink.RangeKey: Settings.MaxRangeKilometers,
                                           WatchLink.DeletedKey: Store.Deleted.sorted(),
                                           WatchLink.HiddenKey: Store.HiddenBuiltIns.sorted(),
                                           WatchLink.UnitKey: Settings.Unit.rawValue,
                                           WatchLink.StampKey: Date().timeIntervalSince1970]
            try Session.updateApplicationContext(Payload)
            Status = "Sent \(Count) \(Noun) at \(WatchLink.Clock())."
            Flash()
            //If the watch app is open, also send directly: the watch answers, which proves the places arrived.
            if Session.isReachable
            {
                Session.sendMessage(Payload, replyHandler:
                {
                    Reply in
                    let Got = Reply[WatchLink.CountKey] as? Int ?? 0
                    Task { @MainActor in
                        self.Status = "Watch confirmed: it now has \(Got) \(Got == 1 ? "place" : "places") (\(WatchLink.Clock()))."
                    }
                }, errorHandler:
                {
                    Failure in
                    Task { @MainActor in
                        self.Status = "Sent \(Count) \(Noun). The watch app did not answer directly; it will pick them up when it is open."
                    }
                })
            }
            else
            {
                Status = "Sent \(Count) \(Noun) at \(WatchLink.Clock()). The watch gets them when its app is next open."
            }
        }
        catch
        {
            Status = "Could not send: \(error.localizedDescription)"
        }
    }

    private func Flash()
    {
        IsSending = true
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            IsSending = false
        }
    }
    #endif

    // MARK: Receiving (watch)

    #if os(watchOS)
    private func Apply(_ Raw: Data, Range: Double?, Deleted: [String]?, Hidden: [String]?, Unit: String?)
    {
        if let Range
        {
            Settings.MaxRangeKilometers = Range
        }
        if let Unit, let Chosen = DistanceUnit(rawValue: Unit)
        {
            Settings.Unit = Chosen
        }
        guard let Places = try? POIStore.Decode(Raw) else
        {
            return
        }
        Store.Replace(With: Places, Deleted: Deleted.map { Set($0) }, Hidden: Hidden.map { Set($0) })
    }
    #endif

    private func Activated()
    {
        #if os(iOS)
        Send()
        #else
        let Saved = WCSession.default.receivedApplicationContext
        if let Raw = Saved[WatchLink.ContextKey] as? Data
        {
            Apply(Raw, Range: Saved[WatchLink.RangeKey] as? Double, Deleted: Saved[WatchLink.DeletedKey] as? [String],
                  Hidden: Saved[WatchLink.HiddenKey] as? [String],
                  Unit: Saved[WatchLink.UnitKey] as? String)
        }
        #endif
    }

    // MARK: WCSessionDelegate (called off the main actor)

    nonisolated func session(_ Session: WCSession, activationDidCompleteWith State: WCSessionActivationState, error: Error?)
    {
        Task { @MainActor in
            self.Activated()
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ Session: WCSession)
    {
    }

    nonisolated func sessionDidDeactivate(_ Session: WCSession)
    {
        //Switching to another paired watch: start over with the new one.
        WCSession.default.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ Session: WCSession)
    {
        Task { @MainActor in
            self.Send()
        }
    }
    #endif

    #if os(watchOS)
    nonisolated func session(_ Session: WCSession, didReceiveMessage Message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void)
    {
        guard let Raw = Message[WatchLink.ContextKey] as? Data,
              let Places = try? POIStore.Decode(Raw) else
        {
            replyHandler([WatchLink.CountKey: -1])
            return
        }
        replyHandler([WatchLink.CountKey: Places.count])
        let Range = Message[WatchLink.RangeKey] as? Double
        let Deleted = Message[WatchLink.DeletedKey] as? [String]
        let Hidden = Message[WatchLink.HiddenKey] as? [String]
        let Unit = Message[WatchLink.UnitKey] as? String
        Task { @MainActor in
            self.Apply(Raw, Range: Range, Deleted: Deleted, Hidden: Hidden, Unit: Unit)
        }
    }

    nonisolated func session(_ Session: WCSession, didReceiveApplicationContext Context: [String: Any])
    {
        guard let Raw = Context[WatchLink.ContextKey] as? Data else
        {
            return
        }
        let Range = Context[WatchLink.RangeKey] as? Double
        let Deleted = Context[WatchLink.DeletedKey] as? [String]
        let Hidden = Context[WatchLink.HiddenKey] as? [String]
        let Unit = Context[WatchLink.UnitKey] as? String
        Task { @MainActor in
            self.Apply(Raw, Range: Range, Deleted: Deleted, Hidden: Hidden, Unit: Unit)
        }
    }
    #endif
}
