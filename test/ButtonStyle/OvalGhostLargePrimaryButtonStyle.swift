//
//  OvalGhostLargePrimaryButtonStyle.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2022/4/12.
//

import SwiftUI

struct OvalGhostLargePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .strokeBorder(lineWidth: 1)
                .frame(width: 56, height: 56)
                .foregroundColor(backgroundColor(isPressed: configuration.isPressed))
            
            configuration.label
                .colorMultiply(foregroundColor(isPressed: configuration.isPressed))
                .foregroundColor(foregroundColor(isPressed: configuration.isPressed))
        }
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        !isEnabled ? Color(.colorOutline04) : isPressed ? Color(.colorOutline01) : Color(.colorOutline18)
    }
    
    private func foregroundColor(isPressed: Bool) -> Color {
        !isEnabled ? Color(.colorIcon01) : isPressed ? Color(.colorIcon15) : Color(.colorIcon16)
    }
}
