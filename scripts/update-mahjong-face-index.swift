import Files
import Foundation

func shell(launchPath: String, arguments: [String]) -> String? {
    let task = Process()
    task.launchPath = launchPath
    task.arguments = arguments

    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)

    return output
}

struct Category: Codable {
    let id: String
    let name: String
    struct Item: Codable {
        let id: String
        let path: String
        let width: Int
        let height: Int
    }
    let content: [Item]
}

extension Category.Item {
    init(folderName: String, file: File) {
        let result = shell(launchPath: "/usr/bin/file", arguments: [file.path])!
            .components(separatedBy: ", ")
            .first(where: { $0.contains(" x ") })!
            .components(separatedBy: " x ")
            .map { $0.replacingOccurrences(of: "\n", with: "") }

        self.init(
            id: "[\(categoryInfo[folderName]!.shortenedName):\(file.nameExcludingExtension)]",
            path: "\(folderName)/\(file.name)",
            width: Int(result[0])!,
            height: Int(result[1])!
        )
    }
}

extension Category {
    func validate() {
        let itemsWithDuplicatedId = Dictionary(grouping: self.content, by: { $0.id })
            .filter { (key, value) in value.count > 1 }
        if (itemsWithDuplicatedId.count > 0) {
            print("\(self.name) contains duplicated id \(itemsWithDuplicatedId.keys)")
            print("\(itemsWithDuplicatedId)")
        }
    }
}

struct CategoryInfo {
    let shortenedName: String
    let chineseName: String
    let order: Int
}

let categoryInfo: [String: CategoryInfo] = [
    "face2017": .init(shortenedName: "f", chineseName: "麻将", order: 0),
    "animal2017": .init(shortenedName: "a", chineseName: "动物", order: 1),
    "bundam2017": .init(shortenedName: "b", chineseName: "高达", order: 2),
    "carton2017": .init(shortenedName: "c", chineseName: "动漫", order: 3),
    "device2017": .init(shortenedName: "d", chineseName: "硬件", order: 4),
    "goose2017": .init(shortenedName: "g", chineseName: "白鹅", order: 5)
]

func main() throws {
    var projectRoot = FileSystem().currentFolder
    while projectRoot.name != "Stage1st-Reader" {
        guard let newRoot = projectRoot.parent else {
            fatalError("Failed to find project root")
        }
        projectRoot = newRoot
    }

    let mahjongRoot = try projectRoot
        .subfolder(named: "Stage1st")
        .subfolder(named: "Resources")
        .subfolder(named: "Mahjong")

    let mahjongCategories = mahjongRoot.makeSubfolderSequence()
        .filter { $0.name.hasSuffix("2017") }
        .sorted { (lhs: Folder, rhs: Folder) -> Bool in
            return categoryInfo[lhs.name]!.order < categoryInfo[rhs.name]!.order
        }
        .map { (folder) in
            return Category(
                id: folder.name,
                name: categoryInfo[folder.name]!.chineseName,
                content: folder.makeFileSequence().map { (file: File) in
                    return Category.Item(folderName: folder.name, file: file)
                }
            )
        }

    mahjongCategories.forEach { (category) in
        category.validate()
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted]
    let encodedData = try encoder.encode(mahjongCategories)
    let indexFile = try mahjongRoot.file(named: "index.json")
    try indexFile.write(data: encodedData)
}

try main()
