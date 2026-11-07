//
//  PulseRing.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/7/26.
//  Ported from the pulse layer in RadarDisplayView in HUDViewUI.
//

import SwiftUI

///A disc that grows and fades again and again, to show where the user is on the radar.
struct PulseRing: View
{
    let Diameter: Double
    let Tint: Color

    var body: some View
    {
        Circle()
            .fill(Tint)
            .frame(width: Diameter, height: Diameter)
            .phaseAnimator([false, true])
            {
                Content, Grown in
                Content
                    .scaleEffect(Grown ? 1.6 : 0.5)
                    .opacity(Grown ? 0.0 : 0.8)
            }
            animation:
            {
                _ in
                .linear(duration: 2.0)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
