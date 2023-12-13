//
//  OvalSmallPrimaryButtonStyle.swift
//  iOSCharmander
//
//  Created by DorisWu on 2021/7/16.
//

import SwiftUI

struct OvalSmallPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 16, height: 16)
            .colorMultiply(foregroundColor())
            .padding(8)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(100)
    }
    
    private func foregroundColor() -> Color {
        isEnabled ? Color(.colorIcon15) : Color(.colorIcon01)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        isPressed ? Color(.colorSurface04) : Color(.colorSurface02)
    }
}
