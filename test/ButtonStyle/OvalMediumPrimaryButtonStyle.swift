//
//  OvalMediumPrimaryButtonStyle.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/7/15.
//

import SwiftUI

struct OvalMediumPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    let isFocus: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .colorMultiply(foregroundColor())
            .padding(8)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(100)
    }
    
    private func foregroundColor() -> Color {
        isEnabled ? Color(.colorIcon05) : Color(.colorIcon01)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if isFocus {
            return Color(.colorPrimary)
        } else {
            return isPressed ? Color(.colorSurface04) : Color(.colorSurface02)
        }
    }
}
