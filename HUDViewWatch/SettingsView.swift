//
//  SettingsView.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/5/26.
//

import SwiftUI

///Settings for the radar. Changes go to the watch when the slider is released.
struct SettingsView: View
{
    @Environment(RadarSettings.self) private var Settings
    @Environment(WatchLink.self) private var Link

    var body: some View
    {
        @Bindable var Bound = Settings
        NavigationStack
        {
            Form
            {
                Section
                {
                    LabeledContent("Maximum range")
                    {
                        Text(Settings.MaxRangeKilometers, format: .number.precision(.fractionLength(0)))
                            + Text(" km")
                    }
                    Slider(value: $Bound.MaxRangeKilometers, in: RadarSettings.RangeLimits)
                    {
                        Text("Maximum range")
                    }
                    onEditingChanged:
                    {
                        Editing in
                        //Send once the slider is let go, not for every step of the drag.
                        if Editing == false
                        {
                            Link.Send()
                        }
                    }
                    Button("Reset to \(RadarSettings.DefaultRangeKilometers, format: .number.precision(.fractionLength(0))) km")
                    {
                        Settings.MaxRangeKilometers = RadarSettings.DefaultRangeKilometers
                        Link.Send()
                    }
                }
                header:
                {
                    Text("Radar")
                }
                footer:
                {
                    Text("Places farther away than this are not shown. This is also the distance of the outer ring when the radar is zoomed all the way out. The setting is sent to your Apple Watch.")
                }
                Section
                {
                    Toggle("Crop places to range", isOn: $Bound.CropToRange)
                }
                header:
                {
                    Text("Display")
                }
                footer:
                {
                    Text("On: only places inside the outer ring are shown. Off: places beyond the ring are drawn outside it and move as you zoom, cut off at the edges of the radar.")
                }
                Section
                {
                    Picker("Distances", selection: $Bound.Unit)
                    {
                        ForEach(DistanceUnit.allCases)
                        {
                            Unit in
                            Text(Unit.Title)
                                .tag(Unit)
                        }
                    }
                    .onChange(of: Settings.Unit)
                    {
                        //The watch shows distances in the same units.
                        Link.Send()
                    }
                }
                header:
                {
                    Text("Units")
                }
                Section
                {
                    Stepper("Most places shown: \(Settings.HUDMarkerLimit)", value: $Bound.HUDMarkerLimit, in: RadarSettings.MarkerLimits)
                    Toggle("Lock horizon", isOn: $Bound.HorizonLocked)
                }
                header:
                {
                    Text("Camera View")
                }
                footer:
                {
                    Text("The camera view shows the nearest places in view, up to this many. Locking the horizon holds the line level and puts every place on it.")
                }
                Section
                {
                    Toggle("Show Sun and Moon", isOn: $Bound.ShowSunMoon)
                    Toggle("Show zodiac constellations", isOn: $Bound.ShowZodiac)
                    Toggle("Show other constellations", isOn: $Bound.ShowOtherConstellations)
                    Toggle("Show galaxies", isOn: $Bound.ShowGalaxies)
                }
                header:
                {
                    Text("Sky")
                }
                footer:
                {
                    Text("Shows them on the camera view like places, from the time and where you are. Below the horizon they are faded: you would be looking through the Earth. A constellation is marked at its middle. Other constellations: Carina, Ophiuchus, Orion, the Big Dipper, the Little Dipper and the Southern Cross. Galaxies: Andromeda and the Large and Small Magellanic Clouds.")
                }
                Section("Apple Watch")
                {
                    Text(Link.Status)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
