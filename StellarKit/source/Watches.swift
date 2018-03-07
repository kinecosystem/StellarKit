//
//  Watches.swift
//  StellarKit
//
//  Created by Avi Shevin on 07/03/2018.
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

public struct TxInfo {
    let tx: Transaction
    public let createdAt: String
    public let source: String
    public let hash: String

    public var asset: String? {
        switch tx.operations.first!.body {
        case .PAYMENT (let op): return op.asset.assetCode
        default: return nil
        }
    }

    public var payments: [Payment] {
        return tx.operations.flatMap({ op in
            guard let body = tx.operations.first?.body else {
                return nil
            }

            if case let Operation.Body.PAYMENT(pOP) = body {
                return Payment(source: op.sourceAccount?.publicKey ?? tx.sourceAccount.publicKey!,
                               destination: pOP.destination.publicKey!,
                               amount: Decimal(Double(pOP.amount) / Double(10_000_000)),
                               asset: pOP.asset)
            }

            if case let Operation.Body.CREATE_ACCOUNT(cOP) = body {
                return Payment(source: op.sourceAccount?.publicKey ?? tx.sourceAccount.publicKey!,
                               destination: cOP.destination.publicKey!,
                               amount: Decimal(Double(cOP.balance) / Double(10_000_000)),
                               asset: .ASSET_TYPE_NATIVE)
            }

            return nil
        })
    }

    public var memoText: String? {
        return tx.memo.text
    }

    public var memoData: Data? {
        return tx.memo.data
    }

    public var sequence: UInt64 {
        return tx.seqNum
    }

    init(json: [String: Any]) throws {
        let envB64 = json["envelope_xdr"] as? String
        let envData = Data(base64Encoded: envB64!)
        let envelope = try XDRDecoder(data: envData!).decode(TransactionEnvelope.self)

        tx = envelope.tx
        createdAt = json["created_at"] as! String
        source = json["source_account"] as! String
        hash = json["hash"] as! String
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
        if type_i == OperationType.CREATE_ACCOUNT {
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
    public let emitter: Observable<TxInfo>

    init(eventSource: StellarEventSource) {
        self.eventSource = eventSource

        self.emitter = eventSource.emitter.flatMap({ event -> TxInfo? in
            guard
                let jsonData = event.data?.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                let unwrappedJSON = json,
                let txInfo = try? TxInfo(json: unwrappedJSON)
                else {
                    return nil
            }

            return txInfo
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
