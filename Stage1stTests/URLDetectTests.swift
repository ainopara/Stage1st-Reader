//
//  URLDetectTests.swift
//  Stage1stTests
//
//  Created by Zheng Li on 2019/7/21.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation
import XCTest
@testable import Stage1st

class URLDetectTests: XCTestCase {

    func testDetectURLInReply() {
        let cases = [
            "https://bbs.saraba1st.com/thread-1-1-1.html": "[url]https://bbs.saraba1st.com/thread-1-1-1.html[/url]",
            "[url]https://bbs.saraba1st.com/thread-1-1-1.html[/url]": "[url]https://bbs.saraba1st.com/thread-1-1-1.html[/url]",
            "https://bbs.saraba1st.com/thread-1-1-1.html 中文": "[url]https://bbs.saraba1st.com/thread-1-1-1.html[/url] 中文",
            "https://bbs.saraba1st.com/thread-1-1-1.html中文": "[url]https://bbs.saraba1st.com/thread-1-1-1.html[/url]中文",
            "中文https://bbs.saraba1st.com/thread-1-1-1.html": "中文[url]https://bbs.saraba1st.com/thread-1-1-1.html[/url]",
            "https://bbs.saraba1st.com/search.php?term=Fate": "[url]https://bbs.saraba1st.com/search.php?term=Fate[/url]",
            "https://bbs.saraba1st.com/2b/search.php?mod=forum&searchid=1544&orderby=lastpost&ascdesc=desc&searchsubmit=yes&kw=%E9%AD%94%E5%AD%A6": "[url]https://bbs.saraba1st.com/2b/search.php?mod=forum&searchid=1544&orderby=lastpost&ascdesc=desc&searchsubmit=yes&kw=%E9%AD%94%E5%AD%A6[/url]"
        ]

        for (input, output) in cases {
            XCTAssertEqual(ReplyViewController.processReplyContent(input), output)
        }
    }
}
