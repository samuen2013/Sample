//
//  OvalGhostIconSmallSecondaryButtonStyle.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/7/15.
//

import SwiftUI

struct OvalGhostIconSmallSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    let icon: ImageResource
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            configuration.label
                .font(.system(size: 17, weight: .medium, design: .default))
                .foregroundColor(textColor(isPressed: configuration.isPressed))
            
            Image(icon)
                .resizable()
                .frame(width: 16, height: 16)
                .colorMultiply(iconColor(isPressed: configuration.isPressed))
                .padding(.leading, 8)
        }
        .frame(height: 32)
        .padding(.horizontal, 16)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder()
                .foregroundColor(borderColor(isPressed: configuration.isPressed))
        )
    }
    
    private func borderColor(isPressed: Bool) -> Color {
        !isEnabled ? Color(.colorOutline04) : isPressed ? Color(.colorOutline15) : Color(.colorOutline18)
    }
    
    private func textColor(isPressed: Bool) -> Color {
        !isEnabled ? Color(.colorText06) : isPressed ? Color(.colorText01) : Color(.colorText03)
    }
    
    private func iconColor(isPressed: Bool) -> Color {
        !isEnabled ? Color(.colorIcon01) : isPressed ? Color(.colorIcon05) : Color(.colorIcon16)
    }
}
