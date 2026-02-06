import SwiftUI

enum Screen: String, CaseIterable {
    case mainMenu
    case mainScreen
    case settings
    case warning
    case oplist
    case sysinfo
    case fileManager
    case appList
    case confirm
}

enum UIConstants {
    static let width: CGFloat = 360
    static let height: CGFloat = 640
    static let mainMenuY: CGFloat = 190
    static let warningY: CGFloat = 565
    static let confirmY: CGFloat = 640 - 125
}

enum AppColors {
    static let error = Color(argb: 0xffb93030)
    static let warning = Color(argb: 0xff8b7200)
    static let info = Color(argb: 0xff646464)
    static let ok = Color(argb: 0xff0d6802)
}

extension Color {
    init(argb: UInt32) {
        let alpha = Double((argb >> 24) & 0xff) / 255.0
        let red = Double((argb >> 16) & 0xff) / 255.0
        let green = Double((argb >> 8) & 0xff) / 255.0
        let blue = Double(argb & 0xff) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct OperatorConfig: Codable {
    let version: Int?
    let name: String?
    let uuid: String
    let description: String?
    let icon: String?
    let screen: String?
    let loop: VideoConfig?
    let intro: VideoConfig?
    let transitionIn: TransitionConfig?
    let transitionLoop: TransitionConfig?
    let overlay: OverlayConfig?

    enum CodingKeys: String, CodingKey {
        case version
        case name
        case uuid
        case description
        case icon
        case screen
        case loop
        case intro
        case transitionIn = "transition_in"
        case transitionLoop = "transition_loop"
        case overlay
    }

    var displayName: String {
        guard let name, !name.isEmpty else {
            return "(未命名)"
        }
        return name
    }
}

struct VideoConfig: Codable {
    let file: String?
    let enabled: Bool?
    let duration: Int?
}

struct TransitionConfig: Codable {
    let type: String?
    let options: TransitionOptions?
}

struct TransitionOptions: Codable {
    let duration: Int?
    let backgroundColor: String?
    let image: String?

    enum CodingKeys: String, CodingKey {
        case duration
        case backgroundColor = "background_color"
        case image
    }
}

struct OverlayConfig: Codable {
    let type: String?
    let options: OverlayOptions?
}

struct OverlayOptions: Codable {
    let appearTime: Int?
    let operatorName: String?
    let operatorCode: String?
    let barcodeText: String?
    let auxText: String?
    let staffText: String?

    enum CodingKeys: String, CodingKey {
        case appearTime = "appear_time"
        case operatorName = "operator_name"
        case operatorCode = "operator_code"
        case barcodeText = "barcode_text"
        case auxText = "aux_text"
        case staffText = "staff_text"
    }
}

struct OperatorAsset: Identifiable {
    let config: OperatorConfig
    let baseURL: URL

    var id: String {
        config.uuid
    }
}

struct WarningInfo {
    var title: String
    var description: String
    var accentColor: Color
}
