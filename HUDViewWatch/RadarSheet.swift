//
//  RadarSheet.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//  Replaces RadarViewController in HUDViewUI: the radar, opened from the camera view.
//

import SwiftUI

///The radar as a sheet over the camera view, with a Done button.
struct RadarSheet: View
{
    @ObservedObject var Compass: HeadingProvider
    @Environment(\.dismiss) private var Dismiss

    var body: some View
    {
        NavigationStack
        {
            PhoneRadarView(Compass: Compass)
                .navigationTitle("Radar")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar
                {
                    ToolbarItem(placement: .confirmationAction)
                    {
                        Button("Done")
                        {
                            Dismiss()
                        }
                    }
                }
        }
    }
}
