//
//  Operations.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

private func decodeData(from decoder: XDRDecoder, capacity: Int) throws -> Data {
    var d = Data(capacity: capacity)

    for _ in 0 ..< capacity {
        let decoded = try decoder.decode(UInt8.self)
        d.append(decoded)
    }

    return d
}

public struct CreateAccountOp: XDRCodable, XDREncodableStruct {
    let destination: PublicKey
    let balance: Int64

    public init(from decoder: XDRDecoder) throws {
        destination = try decoder.decode(PublicKey.self)
        balance = try decoder.decode(Int64.self)
    }

    init(destination: PublicKey, balance: Int64) {
        self.destination = destination
        self.balance = balance
    }
}

struct PaymentOp: XDRCodable, XDREncodableStruct {
    let destination: PublicKey
    let asset: Asset
    let amount: Int64

    init(from decoder: XDRDecoder) throws {
        destination = try decoder.decode(PublicKey.self)
        asset = try decoder.decode(Asset.self)
        amount = try decoder.decode(Int64.self)
    }

    init(destination: PublicKey, asset: Asset, amount: Int64) {
        self.destination = destination
        self.asset = asset
        self.amount = amount
    }
}

public struct PathPaymentOp: XDRCodable, XDREncodableStruct {
    let sendAsset: Asset
    let sendMax: Int64
    let destination: PublicKey
    let destAsset: Asset
    let destAmount: Int64
    let path: Array<Asset>

    public init(from decoder: XDRDecoder) throws {
        sendAsset = try decoder.decode(Asset.self)
        sendMax = try decoder.decode(Int64.self)
        destination = try decoder.decode(PublicKey.self)
        destAsset = try decoder.decode(Asset.self)
        destAmount = try decoder.decode(Int64.self)
        path = try decoder.decodeArray(Asset.self)
    }
}

public struct ChangeTrustOp: XDRCodable, XDREncodableStruct {
    let asset: Asset
    let limit: Int64

    public init(from decoder: XDRDecoder) throws {
        asset = try decoder.decode(Asset.self)
        limit = try decoder.decode(Int64.self)
    }

    public init(asset: Asset, limit: Int64 = Int64.max) {
        self.asset = asset
        self.limit = limit
    }
}

public struct AllowTrustOp: XDRCodable, XDREncodableStruct {
    let trustor: PublicKey
    let asset: Data
    let authorize: Bool

    public init(from decoder: XDRDecoder) throws {
        trustor = try decoder.decode(PublicKey.self)

        let discriminant = try decoder.decode(Int32.self)
        if discriminant == AssetType.ASSET_TYPE_CREDIT_ALPHANUM4 {
            asset = try decodeData(from: decoder, capacity: 4)
        }
        else if discriminant == AssetType.ASSET_TYPE_CREDIT_ALPHANUM12 {
            asset = try decodeData(from: decoder, capacity: 12)
        }
        else {
            fatalError("Unsupported asset type: \(discriminant)")
        }

        authorize = try decoder.decode(Bool.self)
    }
}

public struct SetOptionsOp: XDRCodable, XDREncodableStruct {
    let inflationDest: PublicKey?
    let clearFlags: UInt32?
    let setFlags: UInt32?
    let masterWeight: UInt32?
    let lowThreshold: UInt32?
    let medThreshold: UInt32?
    let highThreshold: UInt32?
    let homeDomain: String?
    let signer: Signer?

    public init(from decoder: XDRDecoder) throws {
        inflationDest = try decoder.decodeArray(PublicKey.self).first
        clearFlags = try decoder.decodeArray(UInt32.self).first
        setFlags = try decoder.decodeArray(UInt32.self).first
        masterWeight = try decoder.decodeArray(UInt32.self).first
        lowThreshold = try decoder.decodeArray(UInt32.self).first
        medThreshold = try decoder.decodeArray(UInt32.self).first
        highThreshold = try decoder.decodeArray(UInt32.self).first
        homeDomain = try decoder.decodeArray(String.self).first
        signer = try decoder.decodeArray(Signer.self).first
    }
}

public struct ManageOfferOp: XDRCodable, XDREncodableStruct {
    let buying: Asset
    let selling: Asset
    let amount: Int64
    let price: Price
    let offerId: Int64

    public init(from decoder: XDRDecoder) throws {
        buying = try decoder.decode(Asset.self)
        selling = try decoder.decode(Asset.self)
        amount = try decoder.decode(Int64.self)
        price = try decoder.decode(Price.self)
        offerId = try decoder.decode(Int64.self)
    }
}

public struct CreatePassiveOfferOp: XDRCodable, XDREncodableStruct {
    let buying: Asset
    let selling: Asset
    let amount: Int64
    let price: Price

    public init(from decoder: XDRDecoder) throws {
        buying = try decoder.decode(Asset.self)
        selling = try decoder.decode(Asset.self)
        amount = try decoder.decode(Int64.self)
        price = try decoder.decode(Price.self)
    }
}

public struct AccountMergeOp: XDRCodable, XDREncodableStruct {
    let destination: PublicKey

    public init(from decoder: XDRDecoder) throws {
        destination = try decoder.decode(PublicKey.self)
    }
}

public struct ManageDataOp: XDRCodable, XDREncodableStruct {
    let dataName: String
    let dataValue: Data?

    public init(from decoder: XDRDecoder) throws {
        dataName = try decoder.decode(String.self)

        let data = try decoder.decodeArray(UInt8.self)
        dataValue = data.isEmpty ? nil : Data(bytes: data)
    }
}

public struct Signer: XDRDecodable {
    let key: SignerKey
    let weight: UInt32

    public init(from decoder: XDRDecoder) throws {
        key = try decoder.decode(SignerKey.self)
        weight = try decoder.decode(UInt32.self)
    }
}

public struct Price: XDRDecodable {
    let n: Int32
    let d: Int32

    public init(from decoder: XDRDecoder) throws {
        n = try decoder.decode(Int32.self)
        d = try decoder.decode(Int32.self)
    }
}

