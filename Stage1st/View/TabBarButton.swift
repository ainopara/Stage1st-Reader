//
//  TabBarButton.swift
//  Stage1st
//
//  Created by Zheng Li on 2020/3/8.
//  Copyright © 2020 Renaissance. All rights reserved.
//

import SwiftUI

struct TabBarButton: View {

    @EnvironmentObject var colorManager: ColorManager

    var title: String = ""
    var isSelected: Bool = false
    var width: CGFloat = 90.0

    var body: some View {
        Text(title)
            .font(Font(UIFont.systemFont(ofSize: 14.0)))
            .foregroundColor(colorManager.s1_title)
            .frame(width: width, height: 44.0)
            .background(isSelected ? colorManager.s1_tint_h : .clear)
    }
}

struct TabBarButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TabBarButton(title: "虚拟主播VTB")
            TabBarButton(title: "虚拟主播VTB", isSelected: true)
        }
            .environmentObject(AppEnvironment.current.colorManager)
            .previewLayout(.sizeThatFits)
    }
}
