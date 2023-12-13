//
//  ToolBarButtonStyle.swift
//  iOSCharmander
//
//  Created by 吳文鳳 on 2023/1/4.
//

import SwiftUI

struct ToolBarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 36, height: 36)
            .colorMultiply(foregroundColor())
    }
    
    private func foregroundColor() -> Color {
        isEnabled ? Color(.colorIcon06) : Color(.colorIcon01)
    }
}

