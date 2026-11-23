//
//  HUDViewMacApp.swift
//  HUDViewMac
//
//  Created by Stuart Rankin on 11/22/26.
//

import SwiftUI

///The Mac app: a radar that follows an iPhone running HUDViewWatch with "Send to Mac" turned on.
@main
struct HUDViewMacApp: App
{
    @State private var Receiver = OrientationReceiver()
    @State private var Store = POIStore()
    @State private var Settings = RadarSettings()
    ///The place chosen on the radar and whether the pointer mode is on.
    @State private var Selection = PlaceSelection()

    var body: some Scene
    {
        WindowGroup
        {
            MacRadarView()
                .environment(Receiver)
                .environment(Store)
                .environment(Settings)
                .environment(Selection)
                .onAppear
                {
                    Receiver.Start()
                }
                .frame(minWidth: 640, minHeight: 480)
        }
    }
}
