//
//  MapPickerView.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/5/26.
//

import SwiftUI
import MapKit

///A map for choosing a place's coordinate. Tap to drop a pin, tap somewhere else to move it, or remove it; "Use This Location"
///hands the pin's coordinate back.
struct MapPickerView: View
{
    ///Called with the chosen coordinate when the user confirms.
    let OnChoose: (CLLocationCoordinate2D) -> Void
    @Environment(\.dismiss) private var Dismiss
    @State private var Pin: CLLocationCoordinate2D?
    @State private var Position: MapCameraPosition

    ///- Parameter Start: The place's current coordinate, if it has one; the pin starts there and the map shows it.
    ///- Parameter Here: The user's location, used to center the map when there is no starting coordinate.
    init(Start: CLLocationCoordinate2D?, Here: CLLocation?, OnChoose: @escaping (CLLocationCoordinate2D) -> Void)
    {
        self.OnChoose = OnChoose
        _Pin = State(initialValue: Start)
        if let Start
        {
            _Position = State(initialValue: .region(MKCoordinateRegion(center: Start,
                                                                       span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2))))
        }
        else if let Here
        {
            _Position = State(initialValue: .region(MKCoordinateRegion(center: Here.coordinate,
                                                                       span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4))))
        }
        else
        {
            //Northern California, where the built-in places are.
            _Position = State(initialValue: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 38.0, longitude: -121.5),
                                                                       span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8))))
        }
    }

    var body: some View
    {
        NavigationStack
        {
            MapReader
            {
                Proxy in
                Map(position: $Position)
                {
                    UserAnnotation()
                    if let Pin
                    {
                        Marker("Place", systemImage: "mappin", coordinate: Pin)
                            .tint(.red)
                    }
                }
                .mapControls
                {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                //Taps need their location, which a Button cannot give.
                .onTapGesture
                {
                    Point in
                    if let Tapped = Proxy.convert(Point, from: .local)
                    {
                        Pin = Tapped
                    }
                }
            }
            .safeAreaInset(edge: .bottom)
            {
                VStack
                {
                    if let Pin
                    {
                        Text("\(Pin.latitude.formatted(.number.precision(.fractionLength(5)))), \(Pin.longitude.formatted(.number.precision(.fractionLength(5))))")
                            .monospacedDigit()
                    }
                    else
                    {
                        Text("Tap the map to drop a pin. Tap again to move it.")
                            .foregroundStyle(.secondary)
                    }
                    HStack
                    {
                        Button("Remove Pin", systemImage: "mappin.slash", role: .destructive)
                        {
                            Pin = nil
                        }
                        .buttonStyle(.bordered)
                        .disabled(Pin == nil)
                        Button("Use This Location", systemImage: "checkmark")
                        {
                            if let Pin
                            {
                                OnChoose(Pin)
                                Dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(Pin == nil)
                    }
                }
                .padding()
                .background(.regularMaterial)
            }
            .navigationTitle("Choose Location")
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
            }
        }
    }
}
