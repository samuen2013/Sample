//
//  SolidLargePrimaryButtonStyle.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/7/11.
//

import SwiftUI

struct SolidLargePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    var isLoading = false
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill()
                .foregroundColor(backgroundColor(isPressed: configuration.isPressed))
            
            configuration.label
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundColor(foregroundColor)
        }
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if isLoading {
            return Color(.colorPrimaryActive)
        } else if !isEnabled {
            return Color(.colorSurface06)
        } else {
            return isPressed ? Color(.colorPrimaryActive) : Color(.colorPrimary)
        }
    }
    
    private var foregroundColor: Color {
        isLoading || isEnabled ? Color(.colorText09) : Color(.colorText07)
    }
}
