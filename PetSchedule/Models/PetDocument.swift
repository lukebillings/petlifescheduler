import Foundation

struct PetDocument: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var data: Data
    var dateAdded: Date
    var fileExtension: String

    init(id: UUID = UUID(), name: String, data: Data, dateAdded: Date = .now, fileExtension: String = "") {
        self.id = id
        self.name = name
        self.data = data
        self.dateAdded = dateAdded
        self.fileExtension = fileExtension
    }

    var displayName: String {
        fileExtension.isEmpty ? name : "\(name).\(fileExtension)"
    }

    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }

    var iconName: String {
        switch fileExtension.lowercased() {
        case "pdf":              return "doc.richtext.fill"
        case "jpg", "jpeg",
             "png", "heic":     return "photo.fill"
        case "doc", "docx":     return "doc.fill"
        case "xls", "xlsx":     return "tablecells.fill"
        case "txt":              return "doc.text.fill"
        default:                 return "doc.fill"
        }
    }
}
