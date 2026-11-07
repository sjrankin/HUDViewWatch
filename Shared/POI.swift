//
//  POI.swift
//  HUDViewWatch Watch App
//
//  Created by Stuart Rankin on 10/26/26.
//  Adapted from POI in HUDViewUI. Route waypoints are intentionally not ported.
//

import SwiftUI
import CoreLocation

///A point of interest (landmark or city). Codable so the user's own places can be saved and sent from the iPhone to the watch.
struct POI: Identifiable, Codable, Hashable
{
    var id: UUID
    var Name: String
    var Latitude: Double
    var Longitude: Double
    var Kind: POIType
    var Elevation: Double?
    var Population: Int?
    ///A short note about the place (for example "RWC Office"), or `nil`. Places saved before this existed have none.
    var Description: String?
    ///For the user's edited copy of a built-in place: the `Key` of the built-in place it replaces. `nil` for any other place.
    var ReplacesKey: String?
    ///True to plot the place on the radar (iPhone and watch). A hidden place stays in the lists. Places saved before this existed
    ///are visible.
    var IsVisible: Bool

    init(ID: UUID = UUID(), Name: String, Latitude: Double, Longitude: Double, Kind: POIType,
         Elevation: Double? = nil, Population: Int? = nil, Description: String? = nil, ReplacesKey: String? = nil, IsVisible: Bool = true)
    {
        self.IsVisible = IsVisible
        self.ReplacesKey = ReplacesKey
        self.id = ID
        self.Name = Name
        self.Latitude = Latitude
        self.Longitude = Longitude
        self.Kind = Kind
        self.Elevation = Elevation
        self.Population = Population
        self.Description = Description
    }

    ///Decodes a place, treating a missing `IsVisible` (from a file or message made before it existed) as visible.
    init(from Decoder: Decoder) throws
    {
        let Values = try Decoder.container(keyedBy: CodingKeys.self)
        id = try Values.decode(UUID.self, forKey: .id)
        Name = try Values.decode(String.self, forKey: .Name)
        Latitude = try Values.decode(Double.self, forKey: .Latitude)
        Longitude = try Values.decode(Double.self, forKey: .Longitude)
        Kind = try Values.decode(POIType.self, forKey: .Kind)
        Elevation = try Values.decodeIfPresent(Double.self, forKey: .Elevation)
        Population = try Values.decodeIfPresent(Int.self, forKey: .Population)
        Description = try Values.decodeIfPresent(String.self, forKey: .Description)
        ReplacesKey = try Values.decodeIfPresent(String.self, forKey: .ReplacesKey)
        IsVisible = try Values.decodeIfPresent(Bool.self, forKey: .IsVisible) ?? true
    }

    ///Identifies a built-in place from one launch to the next. A built-in place's `id` is new every launch, so a place that was
    ///deleted or replaced is remembered by this instead. Only meaningful for the built-in data as it was shipped.
    var Key: String
    {
        "\(Name)|\(Latitude)|\(Longitude)"
    }

    var Coordinate: CLLocationCoordinate2D
    {
        CLLocationCoordinate2D(latitude: Latitude, longitude: Longitude)
    }

    ///True if the name is not blank and the coordinate is on the globe.
    var IsValid: Bool
    {
        Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && (-90.0 ... 90.0).contains(Latitude)
            && (-180.0 ... 180.0).contains(Longitude)
    }
}

///Type of point of interest.
enum POIType: String, CaseIterable, Codable, Identifiable
{
    case City
    case Mountain
    case Bridge
    case Park
    case Lake
    case Forest
    case Volcano
    case River
    case Test

    var id: String
    {
        rawValue
    }

    ///SF Symbol drawn inside the marker.
    var Icon: String
    {
        switch self
        {
            case .City:
                return "building.2.fill"

            case .Mountain, .Volcano:
                return "triangle.fill"

            case .Bridge:
                return "water.waves.and.arrow.trianglehead.up"

            case .Park, .Forest:
                return "tree.fill"

            case .Lake:
                return "drop.fill"

            case .River:
                return "water.waves"

            case .Test:
                return "circle.and.line.horizontal"
        }
    }

    var MarkerColor: Color
    {
        switch self
        {
            case .City:
                return .orange

            case .Mountain:
                return .brown

            case .Bridge, .Volcano:
                return .red

            case .Park, .Forest:
                return .green

            case .Lake, .River:
                return .blue

            case .Test:
                return .purple
        }
    }
}
