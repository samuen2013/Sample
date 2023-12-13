//
//  IconNakedMediumSecondaryButtonStyle.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/8/2.
//

import SwiftUI

struct IconNakedMediumSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    var icon: ImageResource? = nil
    let bgColor: ColorResource
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            if let icon {
                Image(icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .colorMultiply(iconColor(isPressed: configuration.isPressed))
                    .padding(.trailing, 8)
            }
            
            configuration.label
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundColor(textColor(isPressed: configuration.isPressed))
        }
        .frame(height: 36)
        .padding(.horizontal, 8)
        .background(Color(configuration.isPressed ? .colorSurface04 : bgColor))
    }
    
    private func textColor(isPressed: Bool) -> Color {
        !isEnabled ? Color(.colorText06) : isPressed ? Color(.colorText01) : Color(.colorText03)
    }
    
    private func iconColor(isPressed: Bool) -> Color {
        !isEnabled ? Color(.colorIcon01) : isPressed ? Color(.colorIcon15) : Color(.colorIcon16)
    }
}
