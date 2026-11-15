//
//  RadarMapKitView.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/14/26.
//

#if os(iOS)
import SwiftUI
import MapKit

///The iPhone's map, drawn by MapKit's own map view and turned by its camera, so the text stays sharp (turning the finished view
///blurs it). It reports the heading the map really has, because MapKit does not always give the map the heading it was asked for,
///for example when zoomed far out, and the caller then turns the view by what is missing.
struct RadarMapKitView: UIViewRepresentable
{
    ///Where the camera looks.
    let Center: CLLocationCoordinate2D
    ///Degrees clockwise from north that point to the top of the map.
    let Heading: Double
    ///Meters from the camera to the ground.
    let Distance: Double
    ///The heading the map actually has, as reported by MapKit; nil until it has reported.
    @Binding var ActualHeading: Double?

    func makeUIView(context: Context) -> MKMapView
    {
        let View = MKMapView()
        View.isUserInteractionEnabled = false
        View.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        //Always the bright map, whatever the phone's appearance.
        View.overrideUserInterfaceStyle = .light
        View.showsCompass = false
        View.showsUserLocation = false
        View.delegate = context.coordinator
        return View
    }

    func makeCoordinator() -> Coordinator
    {
        Coordinator()
    }

    func updateUIView(_ View: MKMapView, context: Context)
    {
        context.coordinator.Actual = $ActualHeading
        let Camera = MKMapCamera(lookingAtCenter: Center, fromDistance: Distance, pitch: 0, heading: Heading)
        View.setCamera(Camera, animated: false)
        context.coordinator.ConfirmSoon(Camera, On: View)
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate
    {
        var Actual: Binding<Double?>?
        private var Pending: Task<Void, Never>?

        ///MapKit drops a camera change that arrives while it is still busy with the last one. While the compass is moving there is
        ///always another change a moment later, but when the phone is held still the dropped one is the last, and the map stayed at
        ///the wrong angle. So, once the updates stop, the final camera is set again a few times.
        func ConfirmSoon(_ Camera: MKMapCamera, On View: MKMapView)
        {
            Pending?.cancel()
            Pending = Task
            {
                for Delay in [0.1, 0.3, 0.8]
                {
                    try? await Task.sleep(for: .seconds(Delay))
                    if Task.isCancelled
                    {
                        return
                    }
                    //A hair different from the last, so MapKit sees a change and does not skip it as a repeat.
                    let Again = MKMapCamera(lookingAtCenter: Camera.centerCoordinate,
                                            fromDistance: Camera.centerCoordinateDistance * (1 + Delay / 1000),
                                            pitch: 0, heading: Camera.heading)
                    View.setCamera(Again, animated: false)
                    Report(View)
                }
            }
        }

        func mapViewDidChangeVisibleRegion(_ View: MKMapView)
        {
            Report(View)
        }

        ///Tells the caller the heading the map has now.
        private func Report(_ View: MKMapView)
        {
            let Now = View.camera.heading
            guard let Actual, Actual.wrappedValue == nil || abs(Actual.wrappedValue! - Now) > 0.1 else
            {
                return
            }
            //Not while SwiftUI is still drawing the view that asked.
            Task
            {
                Actual.wrappedValue = Now
            }
        }
    }
}
#endif
