//
//  OvalOpacityMediumPrimaryButtonStyle.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/7/8.
//

import SwiftUI

struct OvalOpacityMediumPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    var fgPressedColor = Color(.colorIcon05)
    var bgColor = Color(hex: "#121212")
    var bgPressedColor = Color(hex: "#2E2E2E")
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .colorMultiply(Color(isEnabled ? .colorIcon05 : .colorIcon30))
            .padding(8)
            .background(backgroundColor(isPressed: configuration.isPressed).opacity(0.7))
            .cornerRadius(100)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return Color(hex: "#202020")
        } else {
            return isPressed ? bgPressedColor : bgColor
        }
    }
}
