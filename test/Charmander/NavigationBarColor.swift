//
//  NavigationView+CustomColor.swift
//  iOSCharmander
//
//  Created by DorisWu on 2021/6/4.
//

import Foundation
import SwiftUI

struct NavigationBarColor: ViewModifier {
    var backgroundColor: UIColor?
    
    init(backgroundColor: UIColor, titleColor: UIColor, tintColor: UIColor, barButtonColor: UIColor) {
        self.backgroundColor = backgroundColor
        
        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.configureWithTransparentBackground()
        coloredAppearance.backgroundColor = .clear
        coloredAppearance.titleTextAttributes = [.foregroundColor: titleColor]
        coloredAppearance.largeTitleTextAttributes = [.foregroundColor: titleColor]
                     
        let button = UIBarButtonItemAppearance(style: .plain)
        button.normal.titleTextAttributes = [.foregroundColor: barButtonColor]
        coloredAppearance.buttonAppearance = button

        let image = UIImage(named: "icon_general_arrow_left_solid")?
            .scalePreservingAspectRatio(targetSize: CGSize(width: 28, height: 28))
            .withTintColor(barButtonColor, renderingMode: .alwaysOriginal)
        coloredAppearance.setBackIndicatorImage(image, transitionMaskImage: image)
        
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
        UINavigationBar.appearance().compactAppearance = coloredAppearance
        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().tintColor = tintColor
    }

    func body(content: Content) -> some View {
        ZStack{
            content
            
            VStack {
                GeometryReader { geometry in
                    Color(self.backgroundColor ?? .clear)
                        .frame(height: geometry.safeAreaInsets.top)
                        .edgesIgnoringSafeArea(.top)
                    Spacer()
                }
            }
        }
    }
}

extension View {
    func navigationBarColor(_ background: Color, title: Color = Color(.colorText01), tint: Color = Color(.colorIcon03), button: Color = Color(.colorIcon03)) -> some View {
        self.modifier(NavigationBarColor(backgroundColor: UIColor(background), titleColor: UIColor(title), tintColor: UIColor(tint), barButtonColor: UIColor(button)))
    }
    
    func navigationBarColor(backgroundColor: UIColor, titleColor: UIColor, tintColor: UIColor, barButtonColor: UIColor = UIColor(Color(.colorTextPrimary))) -> some View {
        self.modifier(NavigationBarColor(backgroundColor: backgroundColor, titleColor: titleColor, tintColor: tintColor, barButtonColor: barButtonColor))
    }
}

extension UINavigationController {
    // Remove back button text
    open override func viewWillLayoutSubviews() {
        navigationBar.topItem?.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }
}
