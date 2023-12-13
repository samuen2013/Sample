//
//  NakedLargeCenterPrimaryButtonStyle.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/7/11.
//

import SwiftUI

enum NakedLargeCenterType {
    case primary
    case secondary
    case danger
}

struct NakedLargeCenterButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    let type: NakedLargeCenterType
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill()
                .foregroundColor(.clear)
            
            configuration.label
                .font(.system(size: 17, weight: fontWeight, design: .default))
                .foregroundColor(foregroundColor(isPressed: configuration.isPressed))
        }
    }
    
    private var fontWeight: Font.Weight {
        type == .danger ? .semibold : .regular
    }
    
    private func foregroundColor(isPressed: Bool) -> Color {
        if (!isEnabled) {
            return Color(.colorText06)
        }
        
        switch type {
        case .primary:
            return isPressed ? Color(.colorTextPrimaryActive) : Color(.colorTextPrimary)
        case .secondary:
            return isPressed ? Color(.colorText03) : Color(.colorText01)
        case .danger:
            return isPressed ? Color(.colorTextDangerActive) : Color(.colorTextDanger)
        }
    }
}
