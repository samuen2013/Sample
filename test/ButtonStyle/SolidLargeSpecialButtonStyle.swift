//
//  SolidLargeSpecialButtonStyle.swift
//  iOSCharmander
//
//  Created by bensonchuang on 2022/8/23.
//

import SwiftUI

struct SolidLargeSpecialButtonStyle: ButtonStyle {
    var isOn = false
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .foregroundColor(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.colorOutline07), lineWidth: 1)
                        .opacity(isOn ? 1 : 0)
                )
            
            configuration.label
                .foregroundColor(foregroundColor)
        }
    }
    
    private var backgroundColor: Color { isOn ? Color(.colorSurface17) : Color(.colorPrimary) }
    private var foregroundColor: Color { isOn ? Color(.colorTextPrimary) : Color(.colorText09) }
}
