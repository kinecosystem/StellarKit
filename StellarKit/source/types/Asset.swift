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

public enum Asset: XDREncodable, Equatable {
    case ASSET_TYPE_NATIVE
    case ASSET_TYPE_CREDIT_ALPHANUM4 (Alpha4)
    case ASSET_TYPE_CREDIT_ALPHANUM12 (Alpha12)

    public init?(assetCode: String, issuer: String) {
        if assetCode.count <= 4 {
            guard var codeData = assetCode.data(using: .utf8) else {
                return nil
            }

            let extraCount = 4 - assetCode.count
            codeData.append(contentsOf: Array<UInt8>(repeating: 0, count: extraCount))

            let a4 = Alpha4(assetCode: FixedLengthDataWrapper(codeData),
                            issuer: PublicKey
                                .PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(KeyUtils.key(base32: issuer))))
            self = .ASSET_TYPE_CREDIT_ALPHANUM4(a4)

            return
        }

        if assetCode.count <= 12 {
            guard var codeData = assetCode.data(using: .utf8) else {
                return nil
            }

            let extraCount = 12 - assetCode.count
            codeData.append(contentsOf: Array<UInt8>(repeating: 0, count: extraCount))

            let a12 = Alpha12(assetCode: FixedLengthDataWrapper(codeData),
                              issuer: PublicKey
                                .PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(KeyUtils.key(base32: issuer))))
            self = .ASSET_TYPE_CREDIT_ALPHANUM12(a12)

            return
        }

        return nil
    }

    public struct Alpha4: XDREncodableStruct, Equatable {
        let assetCode: FixedLengthDataWrapper
        let issuer: PublicKey

        init(assetCode: FixedLengthDataWrapper, issuer: PublicKey) {
            self.assetCode = assetCode
            self.issuer = issuer
        }

        public static func ==(lhs: Asset.Alpha4, rhs: Asset.Alpha4) -> Bool {
            return (lhs.assetCode == rhs.assetCode && lhs.issuer == rhs.issuer)
        }
    }

    public struct Alpha12: XDREncodableStruct, Equatable {
        let assetCode: FixedLengthDataWrapper
        let issuer: PublicKey

        init(assetCode: FixedLengthDataWrapper, issuer: PublicKey) {
            self.assetCode = assetCode
            self.issuer = issuer
        }

        public static func ==(lhs: Asset.Alpha12, rhs: Asset.Alpha12) -> Bool {
            return (lhs.assetCode == rhs.assetCode && lhs.issuer == rhs.issuer)
        }
    }

    func discriminant() -> Int32 {
        switch self {
        case .ASSET_TYPE_NATIVE: return AssetType.ASSET_TYPE_NATIVE
        case .ASSET_TYPE_CREDIT_ALPHANUM4: return AssetType.ASSET_TYPE_CREDIT_ALPHANUM4
        case .ASSET_TYPE_CREDIT_ALPHANUM12: return AssetType.ASSET_TYPE_CREDIT_ALPHANUM12
        }
    }

    public func toXDR(count: Int32 = 0) -> Data {
        var xdr = discriminant().toXDR()

        switch self {
        case .ASSET_TYPE_NATIVE: break

        case .ASSET_TYPE_CREDIT_ALPHANUM4 (let alpha4):
            xdr.append(alpha4.toXDR())

        case .ASSET_TYPE_CREDIT_ALPHANUM12 (let alpha12):
            xdr.append(alpha12.toXDR())
        }

        return xdr
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
