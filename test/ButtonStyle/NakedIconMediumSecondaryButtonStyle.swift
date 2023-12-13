//
//  NakedIconMediumSecondaryButtonStyle.swift
//  iOSCharmander
//
//  Created by bensonchuang on 2022/2/9.
//

import SwiftUI

struct NakedIconMediumSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    let icon: ImageResource
    let bgColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            configuration.label
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundColor(textColor(isPressed: configuration.isPressed))
            
            Image(icon)
                .resizable()
                .frame(width: 20, height: 20)
                .colorMultiply(iconColor(isPressed: configuration.isPressed))
                .padding(.leading, 8)
        }
        .frame(height: 36)
        .padding(.horizontal, 8)
        .background(configuration.isPressed ? Color(.colorSurface04) : bgColor)
        .cornerRadius(8)
    }
    
    private func textColor(isPressed: Bool) -> Color {
        !isEnabled ? Color(.colorText06) : isPressed ? Color(.colorText01) : Color(.colorText03)
    }
    
    private func iconColor(isPressed: Bool) -> Color {
        !isEnabled ? Color(.colorIcon01) : isPressed ? Color(.colorIcon15) : Color(.colorIcon16)
    }
}
