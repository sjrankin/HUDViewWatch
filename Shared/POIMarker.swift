//
//  POIMarker.swift
//  HUDViewWatch Watch App
//
//  Created by Stuart Rankin on 10/26/26.
//

import SwiftUI

///A colored disc with the POI type's symbol inside. Size is the disc diameter.
struct POIMarker: View
{
    let Kind: POIType
    let Size: Double
    var IsSelected: Bool = false

    var body: some View
    {
        ZStack
        {
            Circle()
                .fill(Kind.MarkerColor)
            if IsSelected
            {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            }
            Image(systemName: Kind.Icon)
                .font(.system(size: Size * 0.55))
                .foregroundStyle(.white)
        }
        .frame(width: Size, height: Size)
    }
}

///The user's own location: a star the same size as a POIMarker.
struct LocationStar: View
{
    let Size: Double
    let StarColor: Color

    var body: some View
    {
        Image(systemName: "star.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(StarColor)
            .frame(width: Size, height: Size)
    }
}
