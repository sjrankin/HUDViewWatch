//
//  DataPanel.swift
//  HUDViewMac
//
//  Created by Stuart Rankin on 11/22/26.
//

import SwiftUI

///The numbers in the latest frame, for checking what the iPhone sends.
struct DataPanel: View
{
    @Environment(OrientationReceiver.self) private var Receiver
    let Frame: OrientationFrame?
    ///Seconds since the frame arrived.
    let Age: Double?

    var body: some View
    {
        Form
        {
            Section("Link")
            {
                LabeledContent("Listener", value: Description(of: Receiver.Status))
                LabeledContent("Last frame", value: Age.map { "\(Int($0)) s ago" } ?? "none")
                LabeledContent("Used", value: "\(Receiver.AcceptedCount)")
                LabeledContent("Ignored (late)", value: "\(Receiver.IgnoredCount)")
                LabeledContent("Unreadable", value: "\(Receiver.UnreadableCount)")
            }
            if let Frame
            {
                if let Fix = Frame.Location
                {
                    Section("Location")
                    {
                        LabeledContent("Latitude", value: Fix.Latitude.formatted(.number.precision(.fractionLength(5))))
                        LabeledContent("Longitude", value: Fix.Longitude.formatted(.number.precision(.fractionLength(5))))
                        LabeledContent("Altitude", value: "\(Fix.Altitude.formatted(.number.precision(.fractionLength(1)))) m")
                        LabeledContent("Accuracy", value: "± \(Fix.HorizontalAccuracy.formatted(.number.precision(.fractionLength(0)))) m")
                    }
                }
                if let Heading = Frame.Heading
                {
                    Section("Heading")
                    {
                        LabeledContent("Degrees", value: Heading.Degrees.formatted(.number.precision(.fractionLength(1))))
                        LabeledContent("North", value: Heading.IsTrueNorth ? "True" : "Magnetic")
                        LabeledContent("Accuracy", value: Heading.Accuracy < 0 ? "Needs calibration"
                                       : "± \(Heading.Accuracy.formatted(.number.precision(.fractionLength(0))))°")
                    }
                }
                if let Motion = Frame.Motion
                {
                    Section("Motion")
                    {
                        LabeledContent("Pitch", value: Degrees(Motion.Pitch))
                        LabeledContent("Roll", value: Degrees(Motion.Roll))
                        LabeledContent("Yaw", value: Degrees(Motion.Yaw))
                        LabeledContent("Gravity", value: Vector(Motion.Gravity))
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    ///Radians as degrees, for display.
    private func Degrees(_ Radians: Double) -> String
    {
        "\((Radians * 180 / .pi).formatted(.number.precision(.fractionLength(1))))°"
    }

    private func Vector(_ V: OrientationFrame.Vector) -> String
    {
        [V.X, V.Y, V.Z].map { $0.formatted(.number.precision(.fractionLength(2))) }.joined(separator: " ")
    }

    private func Description(of Status: OrientationReceiver.State) -> String
    {
        switch Status
        {
            case .Stopped:
                return "Stopped"
            case .Starting:
                return "Starting"
            case .Listening:
                return "Listening"
            case .Failed(let Reason):
                return "Failed: \(Reason)"
        }
    }
}
