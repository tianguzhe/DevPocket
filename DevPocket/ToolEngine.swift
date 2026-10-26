import Foundation

// This layer has no UI or network dependency, so it can be exercised on its own.
enum DeveloperTool: String, CaseIterable, Identifiable, Sendable {
    case json, timestamp, url, base64, aes, qrcode
    var id: String { rawValue }
    var title: String {
        switch self {
        case .json: return "JSON 格式化"
        case .timestamp: return "时间戳转换"
        case .url: return "URL 编解码"
        case .base64: return "Base64 编解码"
        case .aes: return "AES 加解密"
        case .qrcode: return "二维码生成"
        }
    }
    var symbol: String {
        switch self {
        case .json: return "curlybraces"
        case .timestamp: return "clock"
        case .url: return "link"
        case .base64: return "character"
        case .aes: return "lock.open"
        case .qrcode: return "qrcode"
        }
    }
    var subtitle: String {
        switch self {
        case .json: return "给复杂的数据，一点清晰的秩序。"
        case .timestamp: return "在 Unix 时间与可读日期之间，自由转换。"
        case .url: return "处理查询参数里的空格、符号与中文。"
        case .base64: return "把文本编码，或还原成最初的样子。"
        case .aes: return "让密文回到文本，也让加密变得顺手。"
        case .qrcode: return "把文本或网址，变成随手可扫的二维码。"
        }
    }
    var modes: [ToolMode] {
        switch self {
        case .json: return [.jsonPretty, .jsonCompact]
        case .timestamp: return [.seconds, .milliseconds, .date]
        case .url: return [.urlEncode, .urlDecode]
        case .base64: return [.base64Encode, .base64Decode]
        case .aes: return [.aesDecrypt, .aesEncrypt]
        case .qrcode: return [.qrGenerate]
        }
    }
    var actionTitle: String {
        switch self {
        case .json: return "处理 JSON"
        case .timestamp: return "转换时间"
        case .url, .base64: return "开始转换"
        case .aes: return "处理 AES"
        case .qrcode: return "生成二维码"
        }
    }
}

enum ToolMode: String, Identifiable, Sendable {
    case jsonPretty, jsonCompact, seconds, milliseconds, date
    case urlEncode, urlDecode, base64Encode, base64Decode
    case aesDecrypt, aesEncrypt
    case qrGenerate
    var id: String { rawValue }
    var title: String {
        switch self {
        case .jsonPretty: return "格式化"
        case .jsonCompact: return "压缩"
        case .seconds: return "秒 → 日期"
        case .milliseconds: return "毫秒 → 日期"
        case .date: return "日期 → 时间戳"
        case .urlEncode, .base64Encode: return "编码"
        case .urlDecode, .base64Decode: return "解码"
        case .aesDecrypt: return "解密"
        case .aesEncrypt: return "加密"
        case .qrGenerate: return "生成"
        }
    }
}

struct ToolRequest: Sendable {
    let mode: ToolMode
    let input: String
    var sortKeys = true
    var timeZoneID = TimeZone.current.identifier
    var aes = AESOptions()
    var qrCode = QRCodeOptions()
}

enum ToolOutput: Sendable {
    case text(String)
    case qrCode(QRCodeImage)

    var text: String? {
        if case .text(let value) = self { return value }
        return nil
    }
}

struct ToolFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum ToolEngine {
    static func run(_ request: ToolRequest) throws -> ToolOutput {
        guard request.input.utf8.count <= 5_000_000 else {
            throw ToolFailure(message: "内容超过 5 MB，请缩小后再处理。")
        }
        switch request.mode {
        case .jsonPretty, .jsonCompact:
            let object = try JSONSerialization.jsonObject(with: Data(request.input.utf8), options: .fragmentsAllowed)
            var options: JSONSerialization.WritingOptions = [.fragmentsAllowed, .withoutEscapingSlashes]
            if request.mode == .jsonPretty { options.insert(.prettyPrinted) }
            if request.sortKeys { options.insert(.sortedKeys) }
            let data = try JSONSerialization.data(withJSONObject: object, options: options)
            return .text(String(decoding: data, as: UTF8.self))
        case .urlEncode:
            let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
            guard let encoded = request.input.addingPercentEncoding(withAllowedCharacters: unreserved) else {
                throw ToolFailure(message: "这段文本无法进行 URL 编码。")
            }
            return .text(encoded)
        case .urlDecode:
            guard let decoded = request.input.removingPercentEncoding else {
                throw ToolFailure(message: "无效的百分号编码，请检查 % 后是否是两个十六进制字符。")
            }
            return .text(decoded)
        case .base64Encode:
            return .text(Data(request.input.utf8).base64EncodedString())
        case .base64Decode:
            let normalized = String(request.input.filter { !$0.isWhitespace })
            guard let data = Data(base64Encoded: normalized), let decoded = String(data: data, encoding: .utf8) else {
                throw ToolFailure(message: "请输入有效的 Base64 编码，且解码结果必须是 UTF-8 文本。")
            }
            return .text(decoded)
        case .seconds, .milliseconds, .date:
            return .text(try convertTime(request))
        case .aesDecrypt, .aesEncrypt:
            return .text(try AESEngine.run(request.input, decrypt: request.mode == .aesDecrypt, options: request.aes))
        case .qrGenerate:
            return .qrCode(try QRCodeEngine.generate(request.input, options: request.qrCode))
        }
    }

    private static func convertTime(_ request: ToolRequest) throws -> String {
        let value = request.input.trimmingCharacters(in: .whitespacesAndNewlines)
        let zone = TimeZone(identifier: request.timeZoneID) ?? .current
        let date: Date
        if request.mode == .date {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var parsed = iso.date(from: value)
            iso.formatOptions = [.withInternetDateTime]
            parsed = parsed ?? iso.date(from: value)
            let local = DateFormatter()
            local.locale = Locale(identifier: "en_US_POSIX")
            local.timeZone = zone
            local.dateFormat = "yyyy-MM-dd HH:mm:ss"
            local.isLenient = false
            parsed = parsed ?? local.date(from: value)
            guard let parsed else {
                throw ToolFailure(message: "请输入 ISO 8601 日期，或 yyyy-MM-dd HH:mm:ss 格式的本地时间。")
            }
            date = parsed
        } else {
            guard let number = Double(value), number.isFinite else {
                throw ToolFailure(message: "请输入有效的数字时间戳；支持负数和小数。")
            }
            date = Date(timeIntervalSince1970: request.mode == .milliseconds ? number / 1000 : number)
        }
        // Bound the value before converting to integers or calling date formatters.
        let seconds = date.timeIntervalSince1970
        guard seconds.isFinite, (-62_135_596_800...253_402_300_799).contains(seconds) else {
            throw ToolFailure(message: "时间超出可显示范围（公元 0001–9999 年），请确认秒／毫秒单位。")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS ZZZZZ"
        formatter.timeZone = zone
        let local = formatter.string(from: date)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let utc = formatter.string(from: date)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return "本地时间  \(local)\n时区      \(zone.identifier)\nUTC       \(utc)\nISO 8601  \(iso.string(from: date))\n\nUnix 秒    \(Int64(floor(seconds)))\nUnix 毫秒  \(Int64((seconds * 1000).rounded()))"
    }
}
