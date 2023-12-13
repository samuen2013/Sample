//
//  GhostLargeSecondaryButtonStyle.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/7/11.
//

import SwiftUI

struct GhostLargeSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    var isLoading = false
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(lineWidth: 1)
                .foregroundColor(backgroundColor(isPressed: configuration.isPressed))

            configuration.label
                .foregroundColor(foregroundColor(isPressed: configuration.isPressed))
        }
        .contentShape(Rectangle())
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if isLoading {
            return Color(.colorOutline18)
        } else if !isEnabled {
            return Color(.colorOutline04)
        } else {
            return isPressed ? Color(.colorOutline18) : Color(.colorOutline01)
        }
    }
    
    private func foregroundColor(isPressed: Bool) -> Color {
        if isLoading {
            return Color(.colorText03)
        } else if !isEnabled {
            return Color(.colorText06)
        } else {
            return isPressed ? Color(.colorText03) : Color(.colorText01)
        }
    }
}
