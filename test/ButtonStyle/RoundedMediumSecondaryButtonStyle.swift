//
//  RoundedMediumSecondaryButtonStyle.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/7/8.
//

import SwiftUI

struct RoundedMediumSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    var fgPressedColor = Color(.colorIcon15)
    var bgColor = Color(.colorSurface04)
    var bgPressedColor = Color(.colorSurface05)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .colorMultiply(foregroundColor(isPressed: configuration.isPressed))
            .padding(8)
            .background(configuration.isPressed ? bgPressedColor : bgColor)
            .cornerRadius(12)
    }
    
    private func foregroundColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return Color(.colorIcon01)
        } else {
            return isPressed ? fgPressedColor : Color(.colorIcon15)
        }
    }
}
