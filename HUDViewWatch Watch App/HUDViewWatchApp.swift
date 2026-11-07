//
//  HUDViewWatchApp.swift
//  HUDViewWatch Watch App
//
//  Created by Stuart Rankin on 10/26/26.
//

import SwiftUI

@main
struct HUDViewWatch_Watch_AppApp: App
{
    ///The places the iPhone sent, saved on the watch so they are there when the iPhone is not.
    @State private var Store: POIStore
    ///Receives the places from the iPhone. Held for the life of the app so the connection stays up.
    @State private var Link: WatchLink
    ///The maximum range the iPhone sent, saved on the watch.
    @State private var Settings: RadarSettings

    init()
    {
        let TheStore = POIStore()
        _Store = State(initialValue: TheStore)
        let TheSettings = RadarSettings()
        _Settings = State(initialValue: TheSettings)
        _Link = State(initialValue: WatchLink(Store: TheStore, Settings: TheSettings))
    }

    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
                .environment(Store)
                .environment(Link)
                .environment(Settings)
        }
    }
}
