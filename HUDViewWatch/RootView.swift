//
//  RootView.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/4/26.
//

import SwiftUI

///The iPhone app: the radar (the same display as the watch) and the list where places are entered and edited.
struct RootView: View
{
    @Environment(POIStore.self) private var Store
    @Environment(WatchLink.self) private var Link
    ///One compass for both tabs, so the editor's "Use My Location" and the radar share the same fix.
    @StateObject private var Compass = HeadingProvider()

    var body: some View
    {
        TabView
        {
            Tab("HUD", systemImage: "camera.viewfinder")
            {
                HUDView(Compass: Compass)
            }
            Tab("Radar", systemImage: "scope")
            {
                PhoneRadarView(Compass: Compass)
            }
            Tab("Places", systemImage: "mappin.and.ellipse")
            {
                PlacesView(Compass: Compass)
            }
            Tab("Settings", systemImage: "gearshape")
            {
                SettingsView()
            }
        }
        //Every change to the list goes to the watch.
        .onChange(of: Store.Custom)
        {
            Link.Send()
        }
        .onChange(of: Store.Deleted)
        {
            Link.Send()
        }
        .onChange(of: Store.HiddenBuiltIns)
        {
            Link.Send()
        }
    }
}
