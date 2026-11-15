//
//  RadarMapView.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/13/26.
//

import SwiftUI
import MapKit

///The built-in map, drawn behind the radar and out to the edges of its area. It is turned with the radar, so that the direction the
///device points at is at the top, and zoomed so the radar's outer ring is `RangeDistance` meters from the center.
struct RadarMapView: View
{
    ///The user's location, at the center of the radar.
    let Center: CLLocationCoordinate2D
    ///Degrees clockwise from north the device points at; "up" is always where the device points.
    let Heading: Double
    ///Meters from the center to the outer ring.
    let RangeDistance: Double
    ///Diameter of the outer ring in points. The map is scaled so its ground distance matches the ring.
    let RingDiameter: Double
    ///Width and height of the map in points.
    let Size: CGSize

    ///The vertical field of view of the map's camera, in degrees.
    private let FieldOfView = 30.0

    ///How far the camera is from the ground so that the ring's edge is `RangeDistance` meters from the center, whatever the map's
    ///size. Approximate: MapKit does not document the camera's field of view.
    var CameraDistance: Double
    {
        RangeDistance * (Size.height / RingDiameter) / tan((FieldOfView / 2) * Double.pi / 180)
    }

    #if os(iOS)
    ///The heading the iPhone's map really has, which MapKit reports. At far zoom-out it can refuse to turn the map and leave it north-up.
    @State private var ActualHeading: Double?

    ///The angle in degrees the finished view is turned by to make up what MapKit did not turn: none while it follows the heading, so the
    ///text stays sharp, and the whole angle when it does not.
    var Residual: Double
    {
        guard let ActualHeading else
        {
            return 0
        }
        let Raw = (ActualHeading - Heading).truncatingRemainder(dividingBy: 360)
        return Raw > 180 ? Raw - 360 : (Raw < -180 ? Raw + 360 : Raw)
    }
    #endif

    var body: some View
    {
        #if os(iOS)
        RadarMapKitView(Center: Center, Heading: Heading, Distance: CameraDistance, ActualHeading: $ActualHeading)
            .frame(width: Size.width, height: Size.height)
            .rotationEffect(.degrees(Residual))
            .allowsHitTesting(false)
        #else
        //The watch's map ignores the camera heading, so it stays north-up and the view is turned like the radar's own dial (the
        //cardinal letters), which puts the map's north exactly under the radar's "N".
        Map(position: .constant(.camera(MapCamera(centerCoordinate: Center, distance: CameraDistance, heading: 0, pitch: 0))),
            interactionModes: [])
        {
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControlVisibility(.hidden)
        //The watch is always in dark mode, which makes the map dark; this asks for the bright one.
        .environment(\.colorScheme, .light)
        .frame(width: Size.width, height: Size.height)
        .rotationEffect(.degrees(Heading * -1))
        .allowsHitTesting(false)
        #endif
    }
}
