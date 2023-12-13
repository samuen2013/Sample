//
//  SheetMenuButtonStyle.swift
//  iOSCharmander
//
//  Created by davis.cho on 2021/7/13.
//

import Foundation
import SwiftUI

struct SheetMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color(configuration.isPressed ? .colorSurface05 : .colorDropSurface01))
    }
}
