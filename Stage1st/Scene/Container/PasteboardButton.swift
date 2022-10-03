//
//  PasteboardButton.swift
//  Stage1st
//
//  Created by Zheng Li on 2022/10/3.
//  Copyright © 2022 Renaissance. All rights reserved.
//

import SwiftUI

struct PasteboardButton: View {
    @EnvironmentObject var colorManager: ColorManager

    let action: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "link")
                .font(.system(size: 14.0))
            Text("ContainerViewController.PasteboardLinkHint.title")
                .font(.system(size: 14.0))
        }
        .foregroundColor(colorManager.s1_navigationText)
        .frame(width: 160.0, height: 32.0)
        .background(RoundedRectangle(cornerRadius: 3.0).foregroundColor(colorManager.s1_navigationBackground))
        .onTapGesture {
            action()
        }
    }
}

struct PasteboardButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PasteboardButton(action: { })
                .environment(\.locale, .init(identifier: "zh-CN"))
            PasteboardButton(action: { })
                .environment(\.locale, .init(identifier: "en"))
        }
        .environmentObject(AppEnvironment.current.colorManager)
    }
}
