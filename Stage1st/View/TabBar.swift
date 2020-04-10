//
//  TabBar.swift
//  Stage1st
//
//  Created by Zheng Li on 2020/3/8.
//  Copyright © 2020 Renaissance. All rights reserved.
//

import SwiftUI
import Combine

protocol TabBarDataSource {
    var id: Int { get }
    var name: String { get }
}

extension ForumInfo: TabBarDataSource {}

class TabBarState: ObservableObject {
    @Published var dataSource: [TabBarDataSource] = []
    @Published var selectedID: Int?
}

struct TabBar: View {

    @EnvironmentObject var colorManager: ColorManager
    @ObservedObject var states: TabBarState

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0.0) {
                    ForEach(self.states.dataSource, id: \.id) { data in
                        Button(action: {
                            self.states.selectedID = data.id
                        }, label: {
                            TabBarButton(
                                title: data.name,
                                isSelected: self.states.selectedID == data.id,
                                width: self.buttonWidth(containerWidth: proxy.size.width)
                            )
                        })
                    }
                }.buttonStyle(TabBarButtonStyle(colorManager: self.colorManager))
            }
            .background(self.colorManager.s1_tint)
        }
    }

    func buttonWidth(containerWidth: CGFloat) -> CGFloat {
        return max(containerWidth / CGFloat(states.dataSource.count.aibo_clamped(to: 1...)), 90.0)
    }
}

struct TabBarButtonStyle: ButtonStyle {

    let colorManager: ColorManager

    func makeBody(configuration: Configuration) -> some View {
            return configuration.label
                .background(configuration.isPressed ? colorManager.s1_tint_h : colorManager.s1_tint)
    }
}

struct TabBar_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TabBar(states: states1)
            TabBar(states: states2)
            TabBar(states: states3)
            TabBar(states: states4)
        }
            .environmentObject(AppEnvironment.current.colorManager)
            .previewLayout(.fixed(width: 400.0, height: 100.0))

    }

    static let states1: TabBarState = {
        let states = TabBarState()
        states.dataSource = [
            ForumInfo(id: 1, name: "外野"),
            ForumInfo(id: 2, name: "内野"),
            ForumInfo(id: 3, name: "动漫论坛"),
            ForumInfo(id: 4, name: "游戏论坛"),
            ForumInfo(id: 5, name: "PC 数码")
        ]
        states.selectedID = 3
        return states
    }()

    static let states2: TabBarState = {
        let states = TabBarState()
        states.dataSource = [
            ForumInfo(id: 3, name: "动漫论坛"),
            ForumInfo(id: 4, name: "游戏论坛"),
            ForumInfo(id: 5, name: "PC 数码")
        ]
        states.selectedID = 3
        return states
    }()

    static let states3: TabBarState = {
        let states = TabBarState()
        states.dataSource = [
            ForumInfo(id: 1, name: "外野"),
        ]
        return states
    }()

    static let states4: TabBarState = {
        let states = TabBarState()
        return states
    }()
}
