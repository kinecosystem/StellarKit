//
//  Watches.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import KinUtil

public struct Payment {
    public var source: String
    public var destination: String
    public var amount: Decimal
    public var asset: Asset
}

public struct TxEvent: Decodable, Equatable {
    public let hash: String
    public let created_at: Date
    public let source_account: String
    public let envelope: TransactionEnvelope
    public let meta: TransactionMeta

    enum CodingKeys: String, CodingKey {
        case hash
        case created_at
        case source_account
        case envelope = "envelope_xdr"
        case meta = "result_meta_xdr"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.hash = try container.decode(String.self, forKey: .hash)
        self.created_at = try container.decode(Date.self, forKey: .created_at)
        self.source_account = try container.decode(String.self, forKey: .source_account)

        let eb64 = try container.decode(String.self, forKey: .envelope)
        self.envelope = try XDRDecoder(data: Data(base64Encoded: eb64)!)
            .decode(TransactionEnvelope.self)

        let xb64 = try container.decode(String.self, forKey: .meta)
        self.meta = try XDRDecoder(data: Data(base64Encoded: xb64)!)
            .decode(TransactionMeta.self)
    }

    public static func ==(lhs: TxEvent, rhs: TxEvent) -> Bool {
        return lhs.hash == rhs.hash
    }
}

extension TxEvent {
    public var memoText: String? {
        return envelope.tx.memo.text
    }

    public var memoData: Data? {
        return envelope.tx.memo.data
    }

    public var payments: [Payment] {
        return envelope.tx.operations.flatMap({ op in
            if case let Operation.Body.PAYMENT(pOP) = op.body {
                return Payment(source: op.sourceAccount?.publicKey ?? source_account,
                               destination: pOP.destination.publicKey!,
                               amount: Decimal(Double(pOP.amount) / Double(10_000_000)),
                               asset: pOP.asset)
            }

            if case let Operation.Body.CREATE_ACCOUNT(cOP) = op.body {
                return Payment(source: op.sourceAccount?.publicKey ?? source_account,
                               destination: cOP.destination.publicKey!,
                               amount: Decimal(Double(cOP.balance) / Double(10_000_000)),
                               asset: .ASSET_TYPE_NATIVE)
            }

            return nil
        })
    }
}

//MARK: -

public struct PaymentEvent: Decodable {
    fileprivate let source_account: String
    fileprivate let type: String
    fileprivate let type_i: Int32
    fileprivate let created_at: Date
    fileprivate let transaction_hash: String

    fileprivate let starting_balance: String?
    fileprivate let funder: String?
    fileprivate let account: String?

    fileprivate let asset_type: String?
    fileprivate let asset_code: String?
    fileprivate let asset_issuer: String?
    fileprivate let from: String?
    fileprivate let to: String?
    fileprivate let amountString: String?

    enum CodingKeys: String, CodingKey {
        case source_account = "source_account"
        case type = "type"
        case type_i = "type_i"
        case created_at = "created_at"
        case transaction_hash = "transaction_hash"
        case starting_balance = "starting_balance"
        case funder = "funder"
        case account = "account"
        case asset_type = "asset_type"
        case asset_code = "asset_code"
        case asset_issuer = "asset_issuer"
        case from = "from"
        case to = "to"
        case amountString = "amount"
    }
}

extension PaymentEvent {
    public var source: String {
        return funder ?? from ?? source_account
    }

    public var destination: String {
        return account ?? to ?? ""
    }

    public var amount: Decimal {
        return Decimal(string: starting_balance ?? amountString ?? "0.0") ?? Decimal(0)
    }

    public var asset: Asset {
        if type_i == OperationType.CREATE_ACCOUNT || asset_type == "native" {
            return .ASSET_TYPE_NATIVE
        }

        if let asset_code = asset_code, let asset_issuer = asset_issuer {
            return Asset(assetCode: asset_code, issuer: asset_issuer)!
        }

        fatalError("Could not determine asset from payment: \(self)")
    }
}

//MARK: -

public class TxWatch {
    public let eventSource: StellarEventSource
    public let emitter: Observable<TxEvent>

    private static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        return df
    }()

    init(eventSource: StellarEventSource) {
        self.eventSource = eventSource

        self.emitter = eventSource.emitter.flatMap({ event -> TxEvent? in
            guard let jsonData = event.data?.data(using: .utf8) else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(TxWatch.formatter)

            guard let tx = try? decoder.decode(TxEvent.self, from: jsonData) else {
                return nil
            }

            return tx
        })
    }

    deinit {
        eventSource.close()
        emitter.unlink()
    }
}

public class PaymentWatch {
    public let eventSource: StellarEventSource
    public let emitter: Observable<PaymentEvent>

    private static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        return df
    }()

    init(eventSource: StellarEventSource) {
        self.eventSource = eventSource

        self.emitter = eventSource.emitter.flatMap({ event -> PaymentEvent? in
            guard let jsonData = event.data?.data(using: .utf8) else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(PaymentWatch.formatter)

            guard let payment = try? decoder.decode(PaymentEvent.self, from: jsonData) else {
                return nil
            }

            return payment
        })
    }

    deinit {
        eventSource.close()
        emitter.unlink()
    }
}
