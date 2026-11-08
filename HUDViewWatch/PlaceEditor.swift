//
//  PlaceEditor.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/4/26.
//

import SwiftUI
import CoreLocation

///The form for a new or existing place. The place is saved (and so sent to the watch) when the user taps Save.
struct PlaceEditor: View
{
    @Bindable var Draft: PlaceDraft
    @ObservedObject var Compass: HeadingProvider
    let OnSave: (POI) -> Void
    ///Deletes the place being edited; `nil` for a new place, which has nothing to delete.
    var OnDelete: (() -> Void)? = nil
    ///True when editing a built-in place: saving makes a copy of it that replaces it.
    var IsBuiltIn: Bool = false
    @State private var ShowingMap = false
    @Environment(\.dismiss) private var Dismiss

    private let CoordinateFormat = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0 ... 6))

    ///Where the map's pin starts: the coordinate in the form, if both fields are filled in.
    var StartCoordinate: CLLocationCoordinate2D?
    {
        guard let Latitude = Draft.Latitude, let Longitude = Draft.Longitude,
              (-90.0 ... 90.0).contains(Latitude), (-180.0 ... 180.0).contains(Longitude) else
        {
            return nil
        }
        return CLLocationCoordinate2D(latitude: Latitude, longitude: Longitude)
    }

    var body: some View
    {
        NavigationStack
        {
            Form
            {
                Section("Place")
                {
                    TextField("Name", text: $Draft.Name)
                    Picker("Type", selection: $Draft.Kind)
                    {
                        ForEach(POIType.UserChoices)
                        {
                            Kind in
                            Label(Kind.rawValue, systemImage: Kind.Icon)
                                .tag(Kind)
                        }
                    }
                    Toggle("Show on Radar", isOn: $Draft.IsVisible)
                }
                if IsBuiltIn
                {
                    Section
                    {
                        Text("This is a built-in place. Saving keeps your changes as your own copy, which replaces it on the radar and on the watch.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Coordinate (degrees)")
                {
                    Button("Choose on Map", systemImage: "map")
                    {
                        ShowingMap = true
                    }
                    TextField("Latitude", value: $Draft.Latitude, format: CoordinateFormat)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Longitude", value: $Draft.Longitude, format: CoordinateFormat)
                        .keyboardType(.numbersAndPunctuation)
                    Button("Use My Current Location", systemImage: "location.fill")
                    {
                        if let Here = Compass.Location
                        {
                            Draft.Latitude = Here.coordinate.latitude
                            Draft.Longitude = Here.coordinate.longitude
                        }
                    }
                    .disabled(Compass.Location == nil)
                }
                Section("Optional")
                {
                    TextField("Elevation (meters)", value: $Draft.Elevation, format: .number)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Population", value: $Draft.Population, format: .number)
                        .keyboardType(.numberPad)
                    TextField("Description", text: $Draft.Note)
                }
                if let OnDelete
                {
                    Section
                    {
                        Button("Delete Place", systemImage: "trash", role: .destructive)
                        {
                            OnDelete()
                            Dismiss()
                        }
                    }
                }
                if let Problem = Draft.Problem
                {
                    Section
                    {
                        Text(Problem)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(Draft.IsNew ? "New Place" : "Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .cancellationAction)
                {
                    Button("Cancel")
                    {
                        Dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction)
                {
                    Button("Save")
                    {
                        if let Place = Draft.Make()
                        {
                            OnSave(Place)
                            Dismiss()
                        }
                    }
                    .disabled(Draft.IsValid == false)
                }
            }
            .onAppear
            {
                Compass.Start()
            }
            .sheet(isPresented: $ShowingMap)
            {
                MapPickerView(Start: StartCoordinate, Here: Compass.Location)
                {
                    Chosen in
                    Draft.Latitude = Chosen.latitude
                    Draft.Longitude = Chosen.longitude
                }
            }
        }
    }
}
