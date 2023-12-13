//
//  GhostMediumSecondaryButtonStyle.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/7/15.
//

import SwiftUI

struct GhostMediumSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(lineWidth: 1)
                .foregroundColor(backgroundColor(isPressed: configuration.isPressed))
            
            configuration.label
                .foregroundColor(foregroundColor(isPressed: configuration.isPressed))
        }
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        !isEnabled ? Color(.colorOutline04) : isPressed ? Color(.colorOutline01) : Color(.colorOutline18)
    }
    
    private func foregroundColor(isPressed: Bool) -> Color {
        !isEnabled ? Color(.colorText06) : isPressed ? Color(.colorText01) : Color(.colorText03)
    }
}
