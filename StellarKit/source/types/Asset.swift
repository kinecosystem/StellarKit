//
//  Asset.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

struct AssetType {
    static let ASSET_TYPE_NATIVE: Int32 = 0
    static let ASSET_TYPE_CREDIT_ALPHANUM4: Int32 = 1
    static let ASSET_TYPE_CREDIT_ALPHANUM12: Int32 = 2
}

public enum Asset: XDRCodable, Equatable {
    case ASSET_TYPE_NATIVE
    case ASSET_TYPE_CREDIT_ALPHANUM4 (Alpha4)
    case ASSET_TYPE_CREDIT_ALPHANUM12 (Alpha12)

    public var assetCode: String {
        switch self {
        case .ASSET_TYPE_NATIVE:
            return "native"
        case .ASSET_TYPE_CREDIT_ALPHANUM4(let a4):
            return (String(bytes: a4.assetCode.wrapped, encoding: .utf8) ?? "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        case .ASSET_TYPE_CREDIT_ALPHANUM12(let a12):
            return (String(bytes: a12.assetCode.wrapped, encoding: .utf8) ?? "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        }
    }

    public var issuer: String? {
        switch self {
        case .ASSET_TYPE_NATIVE:
            return nil
        case .ASSET_TYPE_CREDIT_ALPHANUM4(let a4):
            return a4.issuer.publicKey
        case .ASSET_TYPE_CREDIT_ALPHANUM12(let a12):
            return a12.issuer.publicKey
        }
    }
    
    public init(from decoder: XDRDecoder) throws {
        let discriminant = try decoder.decode(Int32.self)

        switch discriminant {
        case AssetType.ASSET_TYPE_NATIVE:
            self = .ASSET_TYPE_NATIVE
        case AssetType.ASSET_TYPE_CREDIT_ALPHANUM4:
            let a4 = try decoder.decode(Alpha4.self)
            self = .ASSET_TYPE_CREDIT_ALPHANUM4(a4)
        case AssetType.ASSET_TYPE_CREDIT_ALPHANUM12:
            let a12 = try decoder.decode(Alpha12.self)
            self = .ASSET_TYPE_CREDIT_ALPHANUM12(a12)
        default:
            self = .ASSET_TYPE_NATIVE
        }
    }

    public init?(assetCode: String, issuer: String) {
        if assetCode.count <= 4 {
            guard var codeData = assetCode.data(using: .utf8) else {
                return nil
            }

            let extraCount = 4 - assetCode.count
            codeData.append(contentsOf: Array<UInt8>(repeating: 0, count: extraCount))

            let a4 = Alpha4(assetCode: WrappedData4(codeData),
                            issuer: PublicKey
                                .PUBLIC_KEY_TYPE_ED25519(WrappedData32(KeyUtils.key(base32: issuer))))
            self = .ASSET_TYPE_CREDIT_ALPHANUM4(a4)

            return
        }

        if assetCode.count <= 12 {
            guard var codeData = assetCode.data(using: .utf8) else {
                return nil
            }

            let extraCount = 12 - assetCode.count
            codeData.append(contentsOf: Array<UInt8>(repeating: 0, count: extraCount))

            let a12 = Alpha12(assetCode: WrappedData12(codeData),
                              issuer: PublicKey
                                .PUBLIC_KEY_TYPE_ED25519(WrappedData32(KeyUtils.key(base32: issuer))))
            self = .ASSET_TYPE_CREDIT_ALPHANUM12(a12)

            return
        }

        return nil
    }

    public struct Alpha4: XDRCodable, Equatable {
        public init(from decoder: XDRDecoder) throws {
            assetCode = try decoder.decode(WrappedData4.self)
            issuer = try decoder.decode(PublicKey.self)
        }

        let assetCode: WrappedData4
        let issuer: PublicKey

        init(assetCode: WrappedData4, issuer: PublicKey) {
            self.assetCode = assetCode
            self.issuer = issuer
        }

        public func encode(to encoder: XDREncoder) throws {
            try encoder.encode(assetCode)
            try encoder.encode(issuer)
        }

        public static func ==(lhs: Asset.Alpha4, rhs: Asset.Alpha4) -> Bool {
            return (lhs.assetCode == rhs.assetCode && lhs.issuer == rhs.issuer)
        }
    }

    public struct Alpha12: XDRCodable, Equatable {
        public init(from decoder: XDRDecoder) throws {
            assetCode = try decoder.decode(WrappedData12.self)
            issuer = try decoder.decode(PublicKey.self)
        }

        let assetCode: WrappedData12
        let issuer: PublicKey

        init(assetCode: WrappedData12, issuer: PublicKey) {
            self.assetCode = assetCode
            self.issuer = issuer
        }

        public func encode(to encoder: XDREncoder) throws {
            try encoder.encode(assetCode)
            try encoder.encode(issuer)
        }

        public static func ==(lhs: Asset.Alpha12, rhs: Asset.Alpha12) -> Bool {
            return (lhs.assetCode == rhs.assetCode && lhs.issuer == rhs.issuer)
        }
    }

    private func discriminant() -> Int32 {
        switch self {
        case .ASSET_TYPE_NATIVE: return AssetType.ASSET_TYPE_NATIVE
        case .ASSET_TYPE_CREDIT_ALPHANUM4: return AssetType.ASSET_TYPE_CREDIT_ALPHANUM4
        case .ASSET_TYPE_CREDIT_ALPHANUM12: return AssetType.ASSET_TYPE_CREDIT_ALPHANUM12
        }
    }

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(discriminant())

        switch self {
        case .ASSET_TYPE_NATIVE: break

        case .ASSET_TYPE_CREDIT_ALPHANUM4 (let alpha4):
            try encoder.encode(alpha4)

        case .ASSET_TYPE_CREDIT_ALPHANUM12 (let alpha12):
            try encoder.encode(alpha12)
        }
    }

    func isEqual(asset: Asset) -> Bool {
        switch self {
        case .ASSET_TYPE_NATIVE:
            return asset.discriminant() == self.discriminant()
        case .ASSET_TYPE_CREDIT_ALPHANUM4(let v1):
            if case .ASSET_TYPE_CREDIT_ALPHANUM4(let v2) = asset {
                return v1 == v2
            }
        case .ASSET_TYPE_CREDIT_ALPHANUM12(let v1):
            if case .ASSET_TYPE_CREDIT_ALPHANUM12(let v2) = asset {
                return v1 == v2
            }
        }

        return false
    }

    public static func ==(lhs: Asset, rhs: Asset) -> Bool {
        return lhs.isEqual(asset: rhs)
    }
}
