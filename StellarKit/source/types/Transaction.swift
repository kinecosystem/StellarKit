//
//  Transaction.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import StellarErrors

struct MemoType {
    static let MEMO_NONE: Int32 = 0
    static let MEMO_TEXT: Int32 = 1
    static let MEMO_ID: Int32 = 2
    static let MEMO_HASH: Int32 = 3
    static let MEMO_RETURN: Int32 = 4
}

public enum Memo: XDRCodable {
    case MEMO_NONE
    case MEMO_TEXT (String)
    case MEMO_ID (UInt64)
    case MEMO_HASH (Data)
    case MEMO_RETURN (Data)

    public var text: String? {
        if case let .MEMO_TEXT(text) = self {
            return text
        }

        if case let .MEMO_HASH(data) = self, let s = String(data: data, encoding: .utf8) {
            return s
        }

        return nil
    }

    public var data: Data? {
        if case let .MEMO_HASH(data) = self {
            return data
        }

        return nil
    }

    public init(_ string: String) throws {
        guard string.utf8.count <= 28 else {
            throw StellarError.memoTooLong(string)
        }

        self = .MEMO_TEXT(string)
    }

    public init(_ data: Data) throws {
        guard data.count <= 32 else {
            throw StellarError.memoTooLong(data)
        }

        self = .MEMO_HASH(data)
    }

    private func discriminant() -> Int32 {
        switch self {
        case .MEMO_NONE: return MemoType.MEMO_NONE
        case .MEMO_TEXT: return MemoType.MEMO_TEXT
        case .MEMO_ID: return MemoType.MEMO_ID
        case .MEMO_HASH: return MemoType.MEMO_HASH
        case .MEMO_RETURN: return MemoType.MEMO_RETURN
        }
    }

    public init(from decoder: XDRDecoder) throws {
        let discriminant = try decoder.decode(Int32.self)

        switch discriminant {
        case MemoType.MEMO_NONE:
            self = .MEMO_NONE
        case MemoType.MEMO_ID:
            self = .MEMO_ID(try decoder.decode(UInt64.self))
        case MemoType.MEMO_TEXT:
            self = .MEMO_TEXT(try decoder.decode(String.self))
        case MemoType.MEMO_HASH:
            self = .MEMO_HASH(try decoder.decode(WrappedData32.self).wrapped)
        default:
            self = .MEMO_NONE
        }
    }

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(discriminant())

        switch self {
        case .MEMO_NONE: break
        case .MEMO_TEXT (let text): try encoder.encode(text)
        case .MEMO_ID (let id): try encoder.encode(id)
        case .MEMO_HASH (let hash): try encoder.encode(WrappedData32(hash))
        case .MEMO_RETURN (let hash): try encoder.encode(WrappedData32(hash))
        }
    }
}

public struct TimeBounds: XDRCodable, XDREncodableStruct {
    public init(from decoder: XDRDecoder) throws {
        minTime = try decoder.decode(UInt64.self)
        maxTime = try decoder.decode(UInt64.self)
    }

    let minTime: UInt64
    let maxTime: UInt64
}

public struct Transaction: XDRCodable {
    public static let MaxMemoLength = 28
    let sourceAccount: PublicKey
    let fee: UInt32
    let seqNum: UInt64
    let timeBounds: TimeBounds?
    let memo: Memo
    let operations: [Operation]
    let reserved: Int32 = 0

    var memoString: String? {
        if case let Memo.MEMO_TEXT(text) = memo {
            return text
        }

        return nil
    }

    public init(sourceAccount: String,
                seqNum: UInt64,
                timeBounds: TimeBounds?,
                memo: Memo,
                fee: UInt32,
                operations: [Operation]) {
        self.init(sourceAccount: .PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: sourceAccount))),
                  seqNum: seqNum,
                  timeBounds: timeBounds,
                  memo: memo,
                  fee: fee,
                  operations: operations)
    }

    init(sourceAccount: PublicKey,
         seqNum: UInt64,
         timeBounds: TimeBounds?,
         memo: Memo,
         fee: UInt32,
         operations: [Operation]) {
        self.sourceAccount = sourceAccount
        self.seqNum = seqNum
        self.timeBounds = timeBounds
        self.memo = memo
        self.fee = fee
        self.operations = operations
    }

    public init(from decoder: XDRDecoder) throws {
        sourceAccount = try decoder.decode(PublicKey.self)
        fee = try decoder.decode(UInt32.self)
        seqNum = try decoder.decode(UInt64.self)
        timeBounds = try decoder.decodeArray(TimeBounds.self).first
        memo = try decoder.decode(Memo.self)
        operations = try decoder.decodeArray(Operation.self)
        _ = try decoder.decode(Int32.self)
    }

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(sourceAccount)
        try encoder.encode(fee)
        try encoder.encode(seqNum)
        try encoder.encodeOptional(timeBounds)
        try encoder.encode(memo)
        try encoder.encode(operations)
        try encoder.encode(reserved)
    }
    
    public func hash(networkId: String) throws -> Data {
        guard let data = networkId.data(using: .utf8)?.sha256 else {
            throw StellarError.dataEncodingFailed
        }
        
        let payload = TransactionSignaturePayload(networkId: WD32(data),
                                                  taggedTransaction: .ENVELOPE_TYPE_TX(self))
        return try XDREncoder.encode(payload).sha256
    }
}

struct EnvelopeType {
    static let ENVELOPE_TYPE_SCP: Int32 = 1
    static let ENVELOPE_TYPE_TX: Int32 = 2
    static let ENVELOPE_TYPE_AUTH: Int32 = 3
}

struct TransactionSignaturePayload: XDREncodableStruct {
    let networkId: WrappedData32
    let taggedTransaction: TaggedTransaction

    var tx: Transaction? {
        if case let .ENVELOPE_TYPE_TX(tx) = taggedTransaction {
            return tx
        }

        return nil
    }

    enum TaggedTransaction: XDREncodable {
        case ENVELOPE_TYPE_TX (Transaction)

        private func discriminant() -> Int32 {
            switch self {
            case .ENVELOPE_TYPE_TX: return EnvelopeType.ENVELOPE_TYPE_TX
            }
        }

        func encode(to encoder: XDREncoder) throws {
            try encoder.encode(discriminant())

            switch self {
            case .ENVELOPE_TYPE_TX (let tx): try encoder.encode(tx)
            }
        }
    }
}

struct DecoratedSignature: XDRCodable, XDREncodableStruct {
    let hint: WrappedData4;
    let signature: [UInt8]

    init(from decoder: XDRDecoder) throws {
        hint = try decoder.decode(WrappedData4.self)
        signature = try decoder.decodeArray(UInt8.self)
    }

    init(hint: WrappedData4, signature: [UInt8]) {
        self.hint = hint
        self.signature = signature
    }
}

public struct TransactionEnvelope: XDRCodable, XDREncodableStruct {
    let tx: Transaction
    private(set) var signatures: [DecoratedSignature]

    public init(from decoder: XDRDecoder) throws {
        tx = try decoder.decode(Transaction.self)
        signatures = try decoder.decodeArray(DecoratedSignature.self)
    }

    init(tx: Transaction, signatures: [DecoratedSignature]) {
        self.tx = tx
        self.signatures = signatures
    }

    mutating func add(signer: Account, networkId: String) throws {
        let m = try tx.hash(networkId: networkId)
        guard let sign = signer.sign else {
            throw StellarError.missingSignClosure
        }

        guard let publicKey = signer.publicKey else {
            throw StellarError.missingPublicKey
        }

        let hint = WrappedData4(KeyUtils.key(base32: publicKey).suffix(4))
        let signature = try DecoratedSignature(hint: hint, signature: sign(Array(m)))

        add(signature: signature)
    }

    mutating func add(signature: DecoratedSignature) {
        signatures.append(signature)
    }
}
