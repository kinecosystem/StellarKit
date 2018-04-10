//
// Ledger.swift
// StellarKit
//
// Created by Kin Foundation.
// Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

typealias AccountID = PublicKey
typealias SequenceNumber = Int64
typealias Thresholds = WrappedData4

public struct AccountEntry: XDRDecodable {
    let accountID: AccountID
    let balance: Int64
    let seqNum: SequenceNumber
    let numSubEntries: UInt32
    let inflationDest: AccountID?
    let flags: UInt32
    let homeDomain: String
    let thresholds: Thresholds
    let signers: [Signer]
    let reserved: Int32 = 0

    public init(from decoder: XDRDecoder) throws {
        accountID = try decoder.decode(AccountID.self)
        balance = try decoder.decode(Int64.self)
        seqNum = try decoder.decode(SequenceNumber.self)
        numSubEntries = try decoder.decode(UInt32.self)
        inflationDest = try decoder.decodeArray(AccountID.self).first
        flags = try decoder.decode(UInt32.self)
        homeDomain = try decoder.decode(String.self)
        thresholds = try decoder.decode(WrappedData4.self)
        signers = try decoder.decodeArray(Signer.self)
        _ = try decoder.decode(Int32.self)
    }
}

public struct TrustLineEntry: XDRDecodable {
    let accountID: AccountID
    public let asset: Asset
    public let balance: Int64
    let limit: Int64
    let flags: UInt32
    let reserved: Int32 = 0

    public var account: String {
        return accountID.publicKey!
    }

    public init(from decoder: XDRDecoder) throws {
        accountID = try decoder.decode(AccountID.self)
        asset = try decoder.decode(Asset.self)
        balance = try decoder.decode(Int64.self)
        limit = try decoder.decode(Int64.self)
        flags = try decoder.decode(UInt32.self)
        _ = try decoder.decode(Int32.self)
    }
}

public struct OfferEntry: XDRDecodable {
    let sellerID: AccountID
    let offerID: UInt64
    let selling: Asset
    let buying: Asset
    let amount: Int64
    let price: Price
    let flags: UInt32
    let reserved: Int32 = 0

    public init(from decoder: XDRDecoder) throws {
        sellerID = try decoder.decode(AccountID.self)
        offerID = try decoder.decode(UInt64.self)
        selling = try decoder.decode(Asset.self)
        buying = try decoder.decode(Asset.self)
        amount = try decoder.decode(Int64.self)
        price = try decoder.decode(Price.self)
        flags = try decoder.decode(UInt32.self)
        _ = try decoder.decode(Int32.self)
    }
}

public struct DataEntry: XDRDecodable {
    let accountID: AccountID
    let dataName: String
    let dataValue: Data
    let reserved: Int32 = 0

    public init(from decoder: XDRDecoder) throws {
        accountID = try decoder.decode(AccountID.self)
        dataName = try decoder.decode(String.self)
        dataValue = try decoder.decode(Data.self)
        _ = try decoder.decode(Int32.self)
    }
}

public struct LedgerEntryType {
    static let ACCOUNT: Int32 = 0
    static let TRUSTLINE: Int32 = 1
    static let OFFER: Int32 = 2
    static let DATA: Int32 = 3
}

public struct LedgerEntry: XDRDecodable {
    public let lastModifiedLedgerSeq: UInt32
    public let data: Data
    let reserved: Int32 = 0

    public enum Data: XDRDecodable {
        case ACCOUNT (AccountEntry)
        case TRUSTLINE (TrustLineEntry)
        case OFFER (OfferEntry)
        case DATA (DataEntry)

        public init(from decoder: XDRDecoder) throws {
            let discriminant = try decoder.decode(Int32.self)

            switch discriminant {
            case LedgerEntryType.ACCOUNT:
                self = .ACCOUNT(try decoder.decode(AccountEntry.self))
            case LedgerEntryType.TRUSTLINE:
                self = .TRUSTLINE(try decoder.decode(TrustLineEntry.self))
            case LedgerEntryType.OFFER:
                self = .OFFER(try decoder.decode(OfferEntry.self))
            case LedgerEntryType.DATA:
                self = .DATA(try decoder.decode(DataEntry.self))
            default:
                fatalError("Unrecognized entry type: \(discriminant)")
            }
        }
    }

    public init(from decoder: XDRDecoder) throws {
        lastModifiedLedgerSeq = try decoder.decode(UInt32.self)
        data = try decoder.decode(LedgerEntry.Data.self)
        _ = try decoder.decode(Int32.self)
    }
}

struct LedgerEntryChangeType {
    static let LEDGER_ENTRY_CREATED: Int32 = 0 // entry was added to the ledger
    static let LEDGER_ENTRY_UPDATED: Int32 = 1 // entry was modified in the ledger
    static let LEDGER_ENTRY_REMOVED: Int32 = 2 // entry was removed from the ledger
    static let LEDGER_ENTRY_STATE: Int32 = 3   // value of the entry
};

public enum LedgerEntryChange: XDRDecodable {
    case LEDGER_ENTRY_CREATED (LedgerEntry)
    case LEDGER_ENTRY_UPDATED (LedgerEntry)
    case LEDGER_ENTRY_REMOVED (LedgerEntry)
    case LEDGER_ENTRY_STATE (LedgerEntry)

    public init(from decoder: XDRDecoder) throws {
        let discriminant = try decoder.decode(Int32.self)

        switch discriminant {
        case LedgerEntryChangeType.LEDGER_ENTRY_CREATED:
            self = .LEDGER_ENTRY_CREATED(try decoder.decode(LedgerEntry.self))
        case LedgerEntryChangeType.LEDGER_ENTRY_UPDATED:
            self = .LEDGER_ENTRY_UPDATED(try decoder.decode(LedgerEntry.self))
        case LedgerEntryChangeType.LEDGER_ENTRY_REMOVED:
            self = .LEDGER_ENTRY_REMOVED(try decoder.decode(LedgerEntry.self))
        case LedgerEntryChangeType.LEDGER_ENTRY_STATE:
            self = .LEDGER_ENTRY_STATE(try decoder.decode(LedgerEntry.self))
        default:
            fatalError("Unrecognized change type: \(discriminant)")
        }
    }
}

public struct OperationMeta: XDRDecodable {
    public let changes: [LedgerEntryChange]

    public init(from decoder: XDRDecoder) throws {
        changes = try decoder.decodeArray(LedgerEntryChange.self)
    }
}

public enum TransactionMeta: XDRDecodable {
    case operations([OperationMeta])

    public init(from decoder: XDRDecoder) throws {
        let discriminant = try decoder.decode(Int32.self)

        switch discriminant {
        case 0:
            self = .operations(try decoder.decodeArray(OperationMeta.self))
        default:
            fatalError("Unsupported case: \(discriminant)")
        }
    }
}
