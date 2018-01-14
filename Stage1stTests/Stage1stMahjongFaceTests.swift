//
//  Stage1stMahjongFaceTests.swift
//  Stage1stTests
//
//  Created by Zheng Li on 14/01/2018.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import XCTest
import Files
@testable import Stage1st

class Stage1stMahjongFaceTests: XCTestCase {
    let categories = S1MahjongFaceView().categories()

    func testCategoriesInIndexAlsoExistInFileSystem() throws {
        let mahjongFaceFolderURL = Bundle.main.bundleURL.appendingPathComponent("Mahjong", isDirectory: true)
        let mahjongFaceFolder = try Folder(path: mahjongFaceFolderURL.path)
        let folderNames = Set(mahjongFaceFolder.subfolders.names)
        for category in categories {
            XCTAssert(folderNames.contains(category.id), "\(category.id) do not have a folder in file system.")
        }
    }

    func testItemsInIndexAlsoExistInFileSystem() throws {
        for category in categories {
            for item in category.content {
                XCTAssert(FileManager.default.fileExists(atPath: item.url.path), "\(item.url.path) should exist.")
            }
        }
    }

    func testItemsInFileSystemAlsoHaveAReferenceFromIndex() throws {
        let allItemsPath = categories.flatMap { $0.content }.map { $0.url.path }
        let allItemsPathSet = Set(allItemsPath)
        XCTAssertEqual(allItemsPath.count, allItemsPathSet.count, "No duplicated reference.")

        let categoryNames = Set(categories.map { $0.id })

        let mahjongFaceFolderURL = Bundle.main.bundleURL.appendingPathComponent("Mahjong", isDirectory: true)
        let mahjongFaceFolder = try Folder(path: mahjongFaceFolderURL.path)
        var counter = 0
        for mahjongFaceFile in mahjongFaceFolder.makeFileSequence(recursive: true, includeHidden: true) {
            let parentFolderName = mahjongFaceFile.parent!.name
            if !categoryNames.contains(parentFolderName) {
                // We only check items in specific folders
                continue
            }
            XCTAssert(allItemsPathSet.contains(mahjongFaceFile.path), "\(mahjongFaceFile.path) should be referenced by index.json")
            counter += 1
        }
        print("\(counter) items checked.")
    }
}
