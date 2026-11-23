//
//  ConnectionBanner.swift
//  HUDViewMac
//
//  Created by Stuart Rankin on 11/22/26.
//

import SwiftUI

///A line over the radar saying whether the iPhone is sending. Hidden while frames are arriving.
struct ConnectionBanner: View
{
    let Status: OrientationReceiver.State
    ///Seconds since the last frame, `nil` if none has come.
    let Age: Double?
    ///True once the phone has sent a GPS fix; the radar cannot place anything before it.
    let HasLocation: Bool

    ///The message, or `nil` when everything is fine.
    var Message: String?
    {
        if case .Failed(let Reason) = Status
        {
            return "Cannot listen for the iPhone: \(Reason)"
        }
        guard let Age else
        {
            return "Waiting for the iPhone. Turn on Send to Mac in HUDViewWatch's Settings."
        }
        if Age > OrientationLink.StaleAfter
        {
            return "No data from the iPhone for \(Int(Age)) seconds."
        }
        if HasLocation == false
        {
            return "The iPhone has not found its location yet."
        }
        return nil
    }

    var body: some View
    {
        if let Message
        {
            Text(Message)
                .font(.callout)
                .foregroundStyle(.white)
                .padding(8)
                .background(.black.opacity(0.7), in: .rect(cornerRadius: 8))
                .padding()
        }
    }
}
