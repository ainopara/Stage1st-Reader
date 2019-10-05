//
//  ContentCell.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/10/3.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import SwiftUI
import Kingfisher

struct ContentCell: View {

    var floor: Floor = Floor(id: 0, author: User(id: 0, name: ""))

    init(floor: Floor) {
        self.floor = floor
    }

    var textColor: Color { Color(hue: 0, saturation: 0, brightness: 0.1137) }
    var backgroundColor: Color { Color(red: 0.96, green: 0.97, blue: 0.92) }

    var body: some View {
        ZStack {
            backgroundColor
            VStack {
                HStack(alignment: .center) {
                    AvatarView(url: floor.author.avatarURL)
                        .padding(.leading, 6.0)

                    Text(floor.author.name)
                        .foregroundColor(textColor)

                    Text("楼主")
                        .font(Font.system(size: 9.0))
                        .foregroundColor(backgroundColor)
                        .padding(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
                        .background(textColor)
                        .cornerRadius(3)

                    Text("05:34")
                        .font(Font.system(size: 12.0))

                    Spacer()
                    Text("#\(floor.indexMark ?? "?")")
                    Image(systemName: "dot.circle")
                        .padding(.trailing, 6.0)
                }
                Text(floor.content)
                    .lineSpacing(2.0)
            }
        }
    }
}

#if DEBUG

struct ContentCell_Previews: PreviewProvider {

    static let floor: Floor = {
        var f = Floor(
            id: 1,
            author: User(id: 206905, name: "ainopara")
        )
        f.indexMark = "1"
        f.content = """
        这次更新改动比较大，先做一下小范围测试比较稳妥。
        有兴趣参加可以私信/回复我您apple ID使用的邮箱，我会发送Testflight测试邀请。
        由于Testflight只支持iOS8以上的系统，所以这次测试无法覆盖使用iOS7的用户，不过app仍然会提供iOS7支持。
        """
        return f
    }()

    static var previews: some View {
        ContentCell(floor: self.floor)
    }
}

#endif

private struct AvatarView: View {
    var url: URL?

    var body: some View {
        KFImage(url)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 40.0, height: 40.0, alignment: .center)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.gray, lineWidth: 0.5))
    }
}
