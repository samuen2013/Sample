//
//  BottomActionButtonStyle.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2023/5/31.
//

import SwiftUI

struct BottomActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? Color(.colorTextPrimary) : Color(.colorText06))
            .font(.system(size: 17, weight: .regular, design: .default))
    }
}
