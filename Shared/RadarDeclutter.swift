//
//  RadarDeclutter.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//

import Foundation

///Thins out the places drawn on the radar so markers do not pile on top of each other, which happens near the center when zoomed out.
///Places are considered in priority order and one is kept only if it is not too close on screen to one already kept. The rest are
///dropped silently. Because the spacing is in screen points, dropped places come back as the radar is zoomed in.
enum RadarDeclutter
{
    ///The fraction of a marker's width that two markers may overlap before one is dropped (0.5 lets them overlap by half).
    static let AllowedOverlap = 0.5

    ///The smallest allowed distance between the centers of two markers, given the markers' diameter.
    static func Spacing(IconSize: Double, Overlap: Double = AllowedOverlap) -> Double
    {
        IconSize * (1.0 - min(max(Overlap, 0.0), 1.0))
    }

    ///Where a place sits relative to the ring center, with north straight up (the dial rotation is applied afterward).
    ///- Parameter Distance: Meters from the user.
    ///- Parameter Bearing: Degrees clockwise from north.
    ///- Parameter RangeDistance: Meters at the outer ring.
    ///- Parameter PlotRadius: Points from the center to the outer ring.
    ///- Parameter ClampsToRange: True to stop places beyond the range at the outer ring.
    static func Position(Distance: Double, Bearing: Double, RangeDistance: Double, PlotRadius: Double, ClampsToRange: Bool) -> CGSize
    {
        let Ratio = ClampsToRange ? min(Distance / RangeDistance, 1.0) : Distance / RangeDistance
        let Angle = Bearing * .pi / 180
        return CGSize(width: PlotRadius * Ratio * sin(Angle), height: PlotRadius * Ratio * cos(Angle) * -1)
    }

    ///The places worth drawing, in their original order (so the draw order is unchanged).
    ///
    ///Priority, highest first: the selected place, the user's own places, cities, everything else. Within a tier the nearest wins.
    ///- Parameter Items: Candidate places.
    ///- Parameter UserPlaceIDs: The ids of places the user created or edited; they always outrank built-in places.
    ///- Parameter SelectedID: The tapped place, which is never dropped (unless it is not in `Items`).
    ///- Parameter MinSpacing: Smallest allowed distance in points between two kept markers, see `Spacing(IconSize:Overlap:)`.
    static func Visible(_ Items: [POIFinder.VisiblePOI],
                        UserPlaceIDs: Set<UUID>,
                        SelectedID: UUID?,
                        RangeDistance: Double,
                        PlotRadius: Double,
                        ClampsToRange: Bool,
                        MinSpacing: Double) -> [POIFinder.VisiblePOI]
    {
        guard MinSpacing > 0, RangeDistance > 0, Items.count > 1 else
        {
            return Items
        }
        let Ranked = Items.sorted
        {
            let Left = Tier($0, UserPlaceIDs: UserPlaceIDs, SelectedID: SelectedID)
            let Right = Tier($1, UserPlaceIDs: UserPlaceIDs, SelectedID: SelectedID)
            return Left == Right ? $0.Distance < $1.Distance : Left < Right
        }

        //Kept positions bucketed into cells MinSpacing wide, so a candidate only has to be compared with its 3 x 3 neighbors.
        var Cells: [Cell: [CGSize]] = [:]
        var Kept: Set<UUID> = []
        for Item in Ranked
        {
            let Spot = Position(Distance: Item.Distance, Bearing: Item.Bearing, RangeDistance: RangeDistance,
                                PlotRadius: PlotRadius, ClampsToRange: ClampsToRange)
            let Home = Cell(X: Int((Spot.width / MinSpacing).rounded(.down)), Y: Int((Spot.height / MinSpacing).rounded(.down)))
            var Crowded = false
            search: for DX in -1 ... 1
            {
                for DY in -1 ... 1
                {
                    for Other in Cells[Cell(X: Home.X + DX, Y: Home.Y + DY)] ?? []
                    {
                        if hypot(Spot.width - Other.width, Spot.height - Other.height) < MinSpacing
                        {
                            Crowded = true
                            break search
                        }
                    }
                }
            }
            if Crowded == false
            {
                Cells[Home, default: []].append(Spot)
                Kept.insert(Item.id)
            }
        }
        return Items.filter { Kept.contains($0.id) }
    }

    ///A square of the spacing grid.
    private struct Cell: Hashable
    {
        let X: Int
        let Y: Int
    }

    ///Lower is more important.
    private static func Tier(_ Item: POIFinder.VisiblePOI, UserPlaceIDs: Set<UUID>, SelectedID: UUID?) -> Int
    {
        if Item.id == SelectedID
        {
            return 0
        }
        if UserPlaceIDs.contains(Item.id)
        {
            return 1
        }
        return Item.Place.Kind == .City ? 2 : 3
    }
}
