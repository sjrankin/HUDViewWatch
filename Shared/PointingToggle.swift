//
//  PointingToggle.swift
//  HUDViewWatch Watch App
//
//  Created by Stuart Rankin on 11/8/26.
//

import SwiftUI

///The round toggle in the corner that turns the pointing mode on and off. On, it is a solid yellow disc with a black arrow and a white
///ring; off, a dim gray disc with a white arrow. The whole disc can be tapped.
struct PointingToggle: View
{
    @Binding var IsOn: Bool
    ///The width and height of the disc.
    let Size: Double

    var body: some View
    {
        Toggle("Track Selected Place", systemImage: "arrow.up.forward", isOn: $IsOn)
            .toggleStyle(PointingToggleStyle(Size: Size))
    }
}

///Draws the pointing toggle as a disc whose look shows whether it is on.
struct PointingToggleStyle: ToggleStyle
{
    let Size: Double

    func makeBody(configuration Configuration: Configuration) -> some View
    {
        Button
        {
            Configuration.isOn.toggle()
        }
        label:
        {
            Image(systemName: "arrow.up.forward")
                .font(.title3.bold())
                .foregroundStyle(Configuration.isOn ? Color.black : Color.white)
                .frame(width: Size, height: Size)
                .background(Configuration.isOn ? Color.yellow : Color.gray.opacity(0.45), in: .circle)
                .overlay
                {
                    Circle()
                        .stroke(Configuration.isOn ? Color.white : Color.white.opacity(0.35), lineWidth: Configuration.isOn ? 3 : 1)
                }
                .contentShape(.circle)
        }
        //A plain button: the bordered ones on the watch stretch across the whole width.
        .buttonStyle(.plain)
        .accessibilityLabel("Track Selected Place")
        .accessibilityValue(Configuration.isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}
