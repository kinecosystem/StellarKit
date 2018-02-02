//
//  Transaction.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

struct MemoType {
    static let MEMO_NONE: Int32 = 0
    static let MEMO_TEXT: Int32 = 1
    static let MEMO_ID: Int32 = 2
    static let MEMO_HASH: Int32 = 3
    static let MEMO_RETURN: Int32 = 4
}

enum Memo: XDRCodable {
    case MEMO_NONE
    case MEMO_TEXT (String)
    case MEMO_ID (UInt64)
    case MEMO_HASH (WrappedData32)
    case MEMO_RETURN (WrappedData32)

    private func discriminant() -> Int32 {
        switch self {
        case .MEMO_NONE: return MemoType.MEMO_NONE
        case .MEMO_TEXT: return MemoType.MEMO_TEXT
        case .MEMO_ID: return MemoType.MEMO_ID
        case .MEMO_HASH: return MemoType.MEMO_HASH
        case .MEMO_RETURN: return MemoType.MEMO_RETURN
        }
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        _ = try container.decode(Int32.self)

        self = .MEMO_NONE
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(discriminant())

        switch self {
        case .MEMO_NONE: break
        case .MEMO_TEXT (let text): try container.encode(text)
        case .MEMO_ID (let id): try container.encode(id)
        case .MEMO_HASH (let hash): try container.encode(hash)
        case .MEMO_RETURN (let hash): try container.encode(hash)
        }
    }
}

struct TimeBounds: XDRCodable {
    let minTime: UInt64
    let maxTime: UInt64
}

public struct Transaction: XDRCodable {
    let sourceAccount: PublicKey
    let fee: UInt32
    let seqNum: UInt64
    let timeBounds: TimeBounds?
    let memo: Memo
    let operations: [Operation]
    let reserved: Int32 = 0

    init(sourceAccount: PublicKey,
         seqNum: UInt64,
         timeBounds: TimeBounds?,
         memo: Memo,
         operations: [Operation]) {
        self.sourceAccount = sourceAccount
        self.seqNum = seqNum
        self.timeBounds = timeBounds
        self.memo = memo
        self.operations = operations

        self.fee = UInt32(100 * operations.count)
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        sourceAccount = try container.decode(PublicKey.self)
        fee = try container.decode(UInt32.self)
        seqNum = try container.decode(UInt64.self)
        timeBounds = try container.decode(Array<TimeBounds>.self).first
        memo = try container.decode(Memo.self)
        operations = try container.decode(Array<Operation>.self)
        _ = try container.decode(Int32.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(sourceAccount)
        try container.encode(fee)
        try container.encode(seqNum)
        try container.encode(timeBounds)
        try container.encode(memo)
        try container.encode(operations)
        try container.encode(reserved)
    }
}

struct EnvelopeType {
    static let ENVELOPE_TYPE_SCP: Int32 = 1
    static let ENVELOPE_TYPE_TX: Int32 = 2
    static let ENVELOPE_TYPE_AUTH: Int32 = 3
}

struct TransactionSignaturePayload: XDREncodable {
    let networkId: WrappedData32
    let taggedTransaction: TaggedTransaction

    enum TaggedTransaction: XDREncodable {
        case ENVELOPE_TYPE_TX (Transaction)

        private func discriminant() -> Int32 {
            switch self {
            case .ENVELOPE_TYPE_TX: return EnvelopeType.ENVELOPE_TYPE_TX
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            try container.encode(discriminant())

            switch self {
            case .ENVELOPE_TYPE_TX (let tx): try container.encode(tx)
            }
        }
    }
}

struct DecoratedSignature: XDRCodable {
    let hint: WrappedData4;
    let signature: Data

    init(hint: WrappedData4, signature: Data) {
        self.hint = hint
        self.signature = signature
    }
}

public struct TransactionEnvelope: XDRCodable {
    let tx: Transaction
    let signatures: [DecoratedSignature]

    init(tx: Transaction, signatures: [DecoratedSignature]) {
        self.tx = tx
        self.signatures = signatures
    }
}
