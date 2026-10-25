import Foundation
import CommonCrypto

enum AESKeyRule: String, CaseIterable, Identifiable, Sendable {
    case packageName, channel, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .packageName: return "Package"
        case .other: return "Other"
        case .channel: return "Channel"
        }
    }
    var inputLabel: String {
        switch self {
        case .packageName: return "包名"
        case .other: return "密钥 KEY"
        case .channel: return "渠道名"
        }
    }
    var placeholder: String {
        switch self {
        case .packageName: return "例如 com.example.app"
        case .channel: return "例如 ExampleChannel"
        case .other: return "输入 16 / 24 / 32 字节密钥"
        }
    }
    var hint: String {
        switch self {
        case .packageName: return "直接使用包名并保留大小写；不足 16 位补 0，超出截取。"
        case .other: return "默认密钥可直接修改；重新选择 Other 恢复默认。"
        case .channel: return "渠道名转小写 → Base64 → 补 0 或截取至 16 位。"
        }
    }
}

enum AESCipherFormat: String, CaseIterable, Identifiable, Sendable {
    case hex, base64
    var id: String { rawValue }
    var title: String { self == .hex ? "Hex" : "Base64" }
}

struct AESOptions: Equatable, Sendable {
    static let defaultKey = "2CiuxU76w89E1OlZ"
    static let defaultIV = "5873087691895047"
    var key = defaultKey
    var packageName = ""
    var channelName = ""
    var iv = defaultIV
    var keyRule: AESKeyRule = .other
    var format: AESCipherFormat = .hex

    // Each scenario keeps its own input; switching rules never reinterprets a
    // previous scenario's generated key as a package or channel name.
    var sourceText: String {
        get {
            switch keyRule {
            case .packageName: return packageName
            case .other: return key
            case .channel: return channelName
            }
        }
        set {
            switch keyRule {
            case .packageName: packageName = newValue
            case .other: key = newValue
            case .channel: channelName = newValue
            }
        }
    }
}

enum AESEngine {
    static func effectiveKey(_ options: AESOptions) throws -> Data {
        let source = options.sourceText
        guard source.utf8.count <= 4096 else {
            throw ToolFailure(message: "密钥、包名或渠道名过长，请控制在 4096 字节以内。")
        }
        let value: String
        switch options.keyRule {
        case .packageName:
            guard !source.isEmpty else {
                throw ToolFailure(message: "请输入 Package 使用的包名。")
            }
            // Reference decrypt() uses the supplied package directly, padding
            // or truncating to 16 characters. Only generateKey() does Base64.
            guard source.utf8.allSatisfy({ $0 < 128 }) else {
                throw ToolFailure(message: "包名规则使用英文、数字或 ASCII 符号；中文密钥请切换到 Other 后直接输入。")
            }
            value = String((source + String(repeating: "0", count: 16)).prefix(16))
        case .other:
            value = source
        case .channel:
            guard !source.isEmpty else {
                throw ToolFailure(message: "请输入 Channel 使用的渠道名。")
            }
            // JavaScript btoa encodes Latin-1 code units, not UTF-8.
            let units = source.lowercased().utf16
            guard units.allSatisfy({ $0 <= 255 }) else {
                throw ToolFailure(message: "原工具的渠道派生仅支持 Latin-1 字符，不能包含中文或 emoji。")
            }
            let base64 = Data(units.map { UInt8($0) }).base64EncodedString()
            value = String((base64 + String(repeating: "0", count: 16)).prefix(16))
        }
        let bytes = Data(value.utf8)
        guard [16, 24, 32].contains(bytes.count) else {
            throw ToolFailure(message: "密钥当前为 \(bytes.count) 字节；AES 需要 16、24 或 32 字节的 UTF-8 密钥。")
        }
        return bytes
    }

    static func run(_ input: String, decrypt: Bool, options: AESOptions) throws -> String {
        guard !input.isEmpty else {
            throw ToolFailure(message: decrypt ? "请先输入需要解密的密文。" : "请先输入需要加密的明文。")
        }
        let key = try effectiveKey(options)
        let iv = Data(options.iv.utf8)
        guard iv.count == kCCBlockSizeAES128 else {
            throw ToolFailure(message: "IV 当前为 \(iv.count) 字节；CBC 模式需要恰好 16 字节的 UTF-8 向量。")
        }
        let data = decrypt ? try decodeCiphertext(input, format: options.format) : Data(input.utf8)
        var output = Data(count: data.count + kCCBlockSizeAES128)
        let capacity = output.count
        var written = 0
        let status = output.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(CCOperation(decrypt ? kCCDecrypt : kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(kCCOptionPKCS7Padding), keyBytes.baseAddress, key.count,
                                ivBytes.baseAddress, source.baseAddress, data.count,
                                destination.baseAddress, capacity, &written)
                    }
                }
            }
        }
        guard status == kCCSuccess else {
            throw ToolFailure(message: decrypt
                ? "解密失败：请检查密钥、IV、密文格式及 PKCS7 填充是否匹配。"
                : "加密失败，请检查密钥与 IV 设置。")
        }
        output.count = written
        if decrypt {
            guard let plaintext = String(data: output, encoding: .utf8) else {
                throw ToolFailure(message: "解密结果不是有效的 UTF-8 文本；请确认密钥、IV 或原始数据类型。")
            }
            return plaintext
        }
        switch options.format {
        case .hex: return output.map { String(format: "%02x", $0) }.joined()
        case .base64: return output.base64EncodedString()
        }
    }

    private static func decodeCiphertext(_ input: String, format: AESCipherFormat) throws -> Data {
        let normalized = String(input.filter { !$0.isWhitespace })
        let data: Data
        switch format {
        case .hex:
            let characters = Array(normalized.utf8)
            guard !characters.isEmpty, characters.count.isMultiple(of: 2),
                  characters.allSatisfy({ nibble($0) != nil }) else {
                throw ToolFailure(message: "Hex 密文需要成对的 0–9、a–f 字符；可包含空格或换行。")
            }
            var bytes = [UInt8]()
            bytes.reserveCapacity(characters.count / 2)
            for index in stride(from: 0, to: characters.count, by: 2) {
                bytes.append(nibble(characters[index])! << 4 | nibble(characters[index + 1])!)
            }
            data = Data(bytes)
        case .base64:
            guard let decoded = Data(base64Encoded: normalized), !decoded.isEmpty else {
                throw ToolFailure(message: "请输入有效的 Base64 密文，允许空格与换行。")
            }
            data = decoded
        }
        guard !data.isEmpty, data.count.isMultiple(of: kCCBlockSizeAES128) else {
            throw ToolFailure(message: "CBC 密文解码后必须是 16 字节的整数倍；当前为 \(data.count) 字节。")
        }
        return data
    }

    private static func nibble(_ character: UInt8) -> UInt8? {
        switch character {
        case 48...57: return character - 48
        case 65...70: return character - 55
        case 97...102: return character - 87
        default: return nil
        }
    }
}
