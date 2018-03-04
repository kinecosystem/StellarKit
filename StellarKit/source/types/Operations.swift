//
//  Operations.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

struct CreateAccountOp: XDRCodable {
    let destination: PublicKey
    let balance: Int64

    init(destination: PublicKey, balance: Int64) {
        self.destination = destination
        self.balance = balance
    }
}

struct PaymentOp: XDRCodable {
    let destination: PublicKey
    let asset: Asset
    let amount: Int64

    init(destination: PublicKey, asset: Asset, amount: Int64) {
        self.destination = destination
        self.asset = asset
        self.amount = amount
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(destination)
        try container.encode(asset)
        try container.encode(amount)
    }
}

struct ChangeTrustOp: XDRCodable {
    let asset: Asset
    let limit: Int64 = Int64.max

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        asset = try container.decode(Asset.self)
        _ = try container.decode(Int64.self)
    }

    init(asset: Asset) {
        self.asset = asset
    }
}

struct SetOptionsOp: XDRCodable {
    let inflationDest: PublicKey?
    let clearFlags: UInt32?
    let setFlags: UInt32?
    let masterWeight: UInt32?
    let lowThreshold: UInt32?
    let medThreshold: UInt32?
    let highThreshold: UInt32?
    let homeDomain: String?
    let signer: Signer?

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        inflationDest = try container.decode(Array<PublicKey>.self).first
        clearFlags = try container.decode(Array<UInt32>.self).first
        setFlags = try container.decode(Array<UInt32>.self).first
        masterWeight = try container.decode(Array<UInt32>.self).first
        lowThreshold = try container.decode(Array<UInt32>.self).first
        medThreshold = try container.decode(Array<UInt32>.self).first
        highThreshold = try container.decode(Array<UInt32>.self).first
        homeDomain = try container.decode(Array<String>.self).first
        signer = try container.decode(Array<Signer>.self).first
    }
}

struct ManageOfferOp: XDRCodable {
    let buying: Asset
    let selling: Asset
    let amount: Int64
    let price: Price
    let offerId: Int64

    struct Price: XDRCodable {
        let n: Int32
        let d: Int32
    }
}

struct CreatePassiveOfferOp: XDRCodable {
    let buying: Asset
    let selling: Asset
    let amount: Int64
    let price: Price

    struct Price: XDRCodable {
        let n: Int32
        let d: Int32
    }
}

struct AccountMergeOp: XDRCodable {
    let destination: PublicKey
}

struct Signer: XDRCodable {
    let key: SignerKey
    let weight: UInt32
}
