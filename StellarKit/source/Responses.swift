//
//  HorizonResponses.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

public enum Responses {
    public struct RequestFailure: Error, Decodable {
        public let type: URL
        public let title: String
        public let status: Int
        public let detail: String
        public let instance: String?
        public let extras: Extras?

        public struct Extras: Decodable {
            public let resultXDR: String

            enum CodingKeys: String, CodingKey {
                case resultXDR = "result_xdr"
            }
        }
    }

    public struct TransactionSuccess: Decodable {
        public let hash: String
        let resultXDR: String

        enum CodingKeys: String, CodingKey {
            case hash
            case resultXDR = "result_xdr"
        }
    }

    public struct AccountDetails: Decodable, CustomStringConvertible {
        public let id: String
        public let accountId: String
        public let sequence: String
        public let balances: [Balance]
        public let data: [String: String]

        public var seqNum: UInt64 {
            return UInt64(sequence) ?? 0
        }

        public struct Balance: Decodable, CustomStringConvertible {
            public let balance: String
            public let assetType: String
            public let assetCode: String?
            public let assetIssuer: String?

            public var balanceNum: Decimal {
                return Decimal(string: balance) ?? Decimal()
            }

            public var asset: Asset? {
                if let assetCode = assetCode, let assetIssuer = assetIssuer {
                    return Asset(assetCode: assetCode, issuer: assetIssuer)
                }

                return Asset.ASSET_TYPE_NATIVE
            }

            public var description: String {
                return """
                balance: \(balance)
                code: \(assetCode ?? "native")
                issuer: \(assetIssuer ?? "n/a")
                """
            }

            enum CodingKeys: String, CodingKey {
                case balance
                case assetType = "asset_type"
                case assetCode = "asset_code"
                case assetIssuer = "asset_issuer"
            }
        }

        public var description: String {
            return """
            id: \(id)
            publicKey: \(accountId)
            sequence: \(sequence)
            balances: \(balances)
            """
        }

        enum CodingKeys: String, CodingKey {
            case id
            case accountId = "account_id"
            case sequence
            case balances
            case data
        }
    }

    public struct Ledgers: Decodable {
        struct Embedded: Decodable {
            let records: [Ledger]
        }

        private let _links: Links
        private let _embedded: Embedded

        var ledgers: [Ledger] { return _embedded.records }
    }

    public struct Ledger: Decodable {
        let _links: Links?
        let id: String
        let paging_token: String
        let hash: String
        let prev_hash: String
        let sequence: Int
        let transaction_count: Int
        let operation_count: Int
        let closed_at: String
        let total_coins: String
        let fee_pool: String
        let base_fee: UInt32?
        let base_reserve: String?
        let base_fee_in_stroops: UInt32?
        let base_reserve_in_stroops: UInt32?
        let max_tx_set_size: Int
        let protocol_version: Int
        let header_xdr: String?
    }

    public struct Transactions: Decodable {
        struct Embedded: Decodable {
            let records: [Transaction]
        }

        private let _links: Links
        private let _embedded: Embedded

        var transactions: [Transaction] { return _embedded.records }
    }

    public struct Transaction: Decodable {
        let _links: Links?
        let id: String
        let paging_token: String
        let hash: String
        let ledger: Int
        let created_at: String
        let source_account: String
        let source_account_sequence: String
        let fee_paid: UInt32
        let operation_count: Int
        let envelope_xdr: String
        let result_xdr: String
        let result_meta_xdr: String
        let fee_meta_xdr: String
        let memo_type: String
        let memo: String?
        let signatures: [String]
    }

    struct Links: Decodable {
        let `self`: Link

        let next: Link?
        let prev: Link?

        let precedes: Link?
        let succeeds: Link?

        let account: Link?
        let ledger: Link?

        let transactions: Link?
        let operations: Link?
        let payments: Link?
        let effects: Link?
    }

    struct Link: Decodable {
        let href: String
        let templated: Bool?
    }
}

extension Responses.RequestFailure {
    public var transactionResult: TransactionResult? {
        if
            let resultXDR = extras?.resultXDR,
            let data = Data(base64Encoded: resultXDR)
        {
            return try? XDRDecoder(data: data).decode(TransactionResult.self)
        }

        return nil
    }
}

extension Responses.TransactionSuccess {
    public var transactionResult: TransactionResult? {
        if let data = Data(base64Encoded: resultXDR) {
            return try? XDRDecoder(data: data).decode(TransactionResult.self)
        }

        return nil
    }
}

extension Responses.Ledger {
    var closedAt: Date {
        return DateFormatter.stellar.date(from: closed_at)!
    }

    var baseFee: UInt32 {
        return (base_fee ?? base_fee_in_stroops)!
    }

    var baseReserve: UInt32 {
        if let base = base_reserve_in_stroops {
            return base
        }

        return UInt32(Double(base_reserve!)!)
    }
}

extension Responses.Transaction {
    var createdAt: Date {
        return DateFormatter.stellar.date(from: created_at)!
    }
}
