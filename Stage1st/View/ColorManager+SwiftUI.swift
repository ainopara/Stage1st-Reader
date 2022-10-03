//
//  ColorManager+SwiftUI.swift
//  Stage1st
//
//  Created by Zheng Li on 2020/3/8.
//  Copyright © 2020 Renaissance. All rights reserved.
//

import SwiftUI

extension ColorManager {
    var s1_tint: Color { Color(colorInPaletteWithID("1")) }
    var s1_tint_h: Color { Color(colorInPaletteWithID("2")) }
    var s1_title: Color { Color(colorInPaletteWithID("3")) }
    var s1_text: Color { Color(colorInPaletteWithID("4")) }
    var s1_navigationText: Color { Color(colorForKey("appearance.navigationbar.tint"))}
    var s1_navigationBackground: Color { Color(colorForKey("appearance.toolbar.bartint"))}
}
