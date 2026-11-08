//
//  POIFinder.swift
//  HUDViewWatch Watch App
//
//  Created by Stuart Rankin on 10/26/26.
//

import Foundation
import CoreLocation

///Finds the points of interest within range of a location.
struct POIFinder
{
    ///A POI with its distance and bearing from the user.
    struct VisiblePOI: Identifiable
    {
        let Place: POI
        ///Meters from the user.
        let Distance: Double
        ///Degrees clockwise from true north (0 ... 360).
        let Bearing: Double
        ///For something in the sky: how many degrees above the horizon it is (negative below it). It then has a direction of its own, and
        ///`Distance` and the place's elevation are not used to find it. `nil` for a place on the ground.
        var SkyElevation: Double? = nil

        ///True for the Sun, the Moon and the constellations.
        var IsSky: Bool
        {
            SkyElevation != nil
        }

        var id: UUID
        {
            Place.id
        }
    }

    ///The places in Places no farther than MaxDistance meters from Location, farthest first so the nearest are drawn on top.
    ///- Parameter TypeFilter: When given and not empty, only places of these kinds are returned.
    static func POIs(In Places: [POI], Near Location: CLLocation, MaxDistance: Double, TypeFilter: Set<POIType>? = nil) -> [VisiblePOI]
    {
        let Wanted = (TypeFilter?.isEmpty ?? true) ? nil : TypeFilter
        let Found: [VisiblePOI] = Places.compactMap
        {
            Item in
            if let Wanted, Wanted.contains(Item.Kind) == false
            {
                return nil
            }
            let Target = CLLocation(latitude: Item.Latitude, longitude: Item.Longitude)
            let Distance = Location.distance(from: Target)
            if Distance > MaxDistance
            {
                return nil
            }
            return VisiblePOI(Place: Item, Distance: Distance,
                              Bearing: Bearing(From: Location.coordinate, To: Item.Coordinate))
        }
        return Found.sorted { $0.Distance > $1.Distance }
    }

    ///Initial great-circle bearing in degrees clockwise from true north.
    static func Bearing(From Start: CLLocationCoordinate2D, To End: CLLocationCoordinate2D) -> Double
    {
        let Lat1 = Start.latitude * .pi / 180
        let Lat2 = End.latitude * .pi / 180
        let DeltaLon = (End.longitude - Start.longitude) * .pi / 180
        let Y = sin(DeltaLon) * cos(Lat2)
        let X = cos(Lat1) * sin(Lat2) - sin(Lat1) * cos(Lat2) * cos(DeltaLon)
        let Degrees = atan2(Y, X) * 180 / .pi
        return (Degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    ///The signed angle in degrees, in -180 ... 180, from one heading to another (positive is clockwise).
    static func AngleDifference(From Start: Double, To End: Double) -> Double
    {
        var Difference = (End - Start).truncatingRemainder(dividingBy: 360.0)
        if Difference > 180.0
        {
            Difference -= 360.0
        }
        else if Difference < -180.0
        {
            Difference += 360.0
        }
        return Difference
    }

    ///The places within a field of view of a camera facing `Facing` degrees from north.
    ///- Parameter FieldOfView: The total width of the view, in degrees.
    static func InFieldOfView(_ Items: [VisiblePOI], Facing: Double, FieldOfView: Double) -> [VisiblePOI]
    {
        Items.filter { abs(AngleDifference(From: Facing, To: $0.Bearing)) <= FieldOfView / 2.0 }
    }
}
