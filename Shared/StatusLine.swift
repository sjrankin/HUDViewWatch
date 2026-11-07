//
//  StatusLine.swift
//  HUDViewWatch Watch App
//
//  Created by Stuart Rankin on 10/26/26.
//

import SwiftUI

///Debug readout of the heading source: north type, accuracy, seconds since the last update, update count.
struct StatusLine: View
{
    @ObservedObject var Compass: HeadingProvider

    func StatusText(At Time: Date) -> String
    {
        var Age = "none"
        if let Last = Compass.LastUpdate
        {
            Age = "\(Int(Time.timeIntervalSince(Last)))s"
        }
        let North = Compass.IsTrueNorth ? "T" : "M"
        let Accuracy = Compass.Accuracy < 0 ? "CAL" : "\(Int(Compass.Accuracy))°"
        var GPS = "gps none"
        if let Fix = Compass.Location
        {
            GPS = "gps ±\(Int(Fix.horizontalAccuracy))m"
        }
        var Text = "\(North) \(Accuracy) age \(Age) #\(Compass.UpdateCount) auth \(Compass.Authorization.rawValue) \(GPS)"
        if let Error = Compass.LastError
        {
            Text += " err: \(Error)"
        }
        return Text
    }

    var body: some View
    {
        TimelineView(.periodic(from: .now, by: 1.0))
        {
            Context in
            Text(StatusText(At: Context.date))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                //Solid backing so the text stays readable over the rings.
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}
