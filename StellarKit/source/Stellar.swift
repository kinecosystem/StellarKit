//
//  Stellar.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import KinUtil

public protocol Account {
    var publicKey: String? { get }

    var sign: ((Data) throws -> Data)? { get }
}

public enum NetworkId: String {
    case test = "Test SDF Network ; September 2015"
    case main = "Public Global Stellar Network ; September 2015"
}

public struct StellarNode {
    public let baseURL: URL

    let networkId: NetworkId

    public init(baseURL: URL, networkId: NetworkId = .test) {
        self.baseURL = baseURL
        self.networkId = networkId
    }
}

typealias WD32 = WrappedData32

/**
 `Stellar` provides an API for communicating with Stellar Horizon servers, with an emphasis on
 supporting non-native assets.
 */
public class Stellar {
    public let node: StellarNode
    public let asset: Asset

    // MARK: -

    /**
     Instantiates an instance of `Stellar`.

     - parameter node: A `StellarNode` instance, describing the network to communicate with.
     - parameter asset: The default `Asset` used by methods which require one.
     */
    public init(node: StellarNode, asset: Asset? = nil) {
        self.node = node
        self.asset = asset ?? .ASSET_TYPE_NATIVE
    }

    // MARK: -

    /**
     Sends a payment to the given account.

     - parameter source: The account from which the payment will be made.
     - parameter destination: The public key of the receiving account, as a base32 string.
     - parameter amount: The amount to be sent.
     - parameter asset: The `Asset` to be sent.  Defaults to the `Asset` specified in the initializer.
     - parameter memo: A short string placed in the MEMO field of the transaction.

     - Returns: A promise which will be signalled with the result of the operation.
     */
    public func payment(source: Account,
                        destination: String,
                        amount: Int64,
                        asset: Asset? = nil,
                        memo: Memo = .MEMO_NONE) -> Promise<String> {
        return balance(account: destination, asset: asset)
            .then { _ -> Promise<Transaction> in
                let op = Operation.paymentOp(destination: destination,
                                             amount: amount,
                                             source: nil,
                                             asset: asset ?? self.asset)

                return self.transaction(source: source, operations: [ op ], memo: memo)
            }
            .then { tx -> Promise<String> in
                let envelope = try self.sign(transaction: tx,
                                             signer: source)

                return self.postTransaction(baseURL: self.node.baseURL, envelope: envelope)
            }
            .transformError(handler: { (error) -> Error in
                if case StellarError.missingAccount = error {
                    return StellarError.destinationNotReadyForAsset(error, asset ?? self.asset)
                }

                if case StellarError.missingBalance = error {
                    return StellarError.destinationNotReadyForAsset(error, asset ?? self.asset)
                }

                return error
            })
    }

    /**
     Establishes trust for a non-native asset.

     - parameter asset: The `Asset` to trust.
     - parameter account: The `Account` which will trust the given asset.

     - Returns: A promise which will be signalled with the result of the operation.
     */
    public func trust(asset: Asset, account: Account) -> Promise<String> {
        let p = Promise<String>()

        guard let destination = account.publicKey else {
            p.signal(StellarError.missingPublicKey)

            return p
        }

        balance(account: destination, asset: asset)
            .then { _ -> Void in
                p.signal("-na-")
            }
            .error { error in
                if let error = error as? StellarError, case StellarError.missingAccount = error {
                    p.signal(error)

                    return
                }

                self.transaction(source: account, operations: [Operation.changeTrustOp(asset: asset)])
                    .then { tx -> Promise<String> in
                        let envelope = try self.sign(transaction: tx,
                                                     signer: account)

                        return self.postTransaction(baseURL: self.node.baseURL, envelope: envelope)
                    }
                    .then { txHash in
                        p.signal(txHash)
                    }
                    .error { error in
                        p.signal(error)
                }
        }

        return p
    }

    /**
     Obtain the balance for a given asset.

     - parameter account: The `Account` whose balance will be retrieved.
     - parameter asset: The `Asset` whose balance will be obtained.  Defaults to the `Asset` specified in the initializer.

     - Returns: A promise which will be signalled with the result of the operation.
     */
    public func balance(account: String, asset: Asset? = nil) -> Promise<Decimal> {
        return accountDetails(account: account)
            .then { accountDetails in
                let p = Promise<Decimal>()

                let asset = asset ?? self.asset

                for balance in accountDetails.balances {
                    let code = balance.assetCode
                    let issuer = balance.assetIssuer

                    if (code == "native" && asset.assetCode == "native") {
                        return p.signal(balance.balanceNum)
                    }

                    if let issuer = issuer, let code = code,
                        Asset(assetCode: code, issuer: issuer) == asset {
                        return p.signal(balance.balanceNum)
                    }
                }

                return p.signal(StellarError.missingBalance)
        }
    }

    public func txWatch(account: String? = nil,
                        lastEventId: String?,
                        descending: Bool = false) -> TxWatch {
        var url = node.baseURL

        if let account = account {
            url = url
                .appendingPathComponent("accounts")
                .appendingPathComponent(account)
        }

        url = url
            .appendingPathComponent("transactions")

        url = URL(string: url.absoluteString + "?order=\(descending ? "desc" : "asc")")!

        if let lastEventId = lastEventId {
            url = URL(string: url.absoluteString + "&cursor=\(lastEventId)")!
        }

        return TxWatch(eventSource: StellarEventSource(url: url))
    }

    public func paymentWatch(account: String? = nil,
                             lastEventId: String?,
                             descending: Bool = false) -> PaymentWatch {
        var url = node.baseURL

        if let account = account {
            url = url
                .appendingPathComponent("accounts")
                .appendingPathComponent(account)
        }

        url = url
            .appendingPathComponent("payments")

        url = URL(string: url.absoluteString + "?order=\(descending ? "desc" : "asc")")!

        if let lastEventId = lastEventId {
            url = URL(string: url.absoluteString + "&cursor=\(lastEventId)")!
        }

        return PaymentWatch(eventSource: StellarEventSource(url: url))
    }

    public func accountDetails(account: String) -> Promise<AccountDetails> {
        let url = node.baseURL.appendingPathComponent("accounts").appendingPathComponent(account)

        return issue(request: URLRequest(url: url))
            .then { data in
                if let horizonError = try? JSONDecoder().decode(HorizonError.self, from: data) {
                    if horizonError.status == 404 {
                        throw StellarError.missingAccount
                    }
                    else {
                        throw StellarError.unknownError(horizonError)
                    }
                }

                return try Promise<AccountDetails>(JSONDecoder().decode(AccountDetails.self, from: data))
        }
    }

    // MARK: -

    public func transaction(source: Account,
                            operations: [Operation],
                            sequence: UInt64 = 0,
                            memo: Memo = .MEMO_NONE) -> Promise<Transaction> {
        let p = Promise<Transaction>()

        guard let sourceKey = source.publicKey else {
            p.signal(StellarError.missingPublicKey)

            return p
        }

        let sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: sourceKey)))

        let comp = { (sequence: UInt64) -> Void in
            let tx = Transaction(sourceAccount: sourcePK,
                                 seqNum: sequence,
                                 timeBounds: nil,
                                 memo: memo,
                                 operations: operations)

            p.signal(tx)
        }

        if sequence > 0 {
            comp(sequence)

            return p
        }

        self.sequence(account: sourceKey)
            .then {
                comp($0 + 1)
            }
            .error { _ in
                p.signal(StellarError.missingSequence)
        }

        return p
    }

    public func sign(transaction tx: Transaction,
                     signer: Account) throws -> TransactionEnvelope {
        guard let publicKey = signer.publicKey else {
            throw StellarError.missingPublicKey
        }

        return try StellarKit.sign(transaction: tx,
                                   signer: signer,
                                   hint: KeyUtils.key(base32: publicKey).suffix(4),
                                   networkId: node.networkId.rawValue)
    }

    public func sequence(account: String) -> Promise<UInt64> {
        return accountDetails(account: account)
            .then { accountDetails in
                return Promise<UInt64>().signal(accountDetails.seqNum)
        }
    }

    public func postTransaction(baseURL: URL, envelope: TransactionEnvelope) -> Promise<String> {
        let envelopeData: Data
        do {
            envelopeData = try Data(XDREncoder.encode(envelope))
        }
        catch {
            return Promise<String>(error)
        }

        guard let urlEncodedEnvelope = envelopeData.base64EncodedString().urlEncoded else {
            return Promise<String>(StellarError.urlEncodingFailed)
        }

        guard let httpBody = ("tx=" + urlEncodedEnvelope).data(using: .utf8) else {
            return Promise<String>(StellarError.dataEncodingFailed)
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("transactions"))
        request.httpMethod = "POST"
        request.httpBody = httpBody

        return issue(request: request)
            .then { data in
                if let horizonError = try? JSONDecoder().decode(HorizonError.self, from: data),
                    let resultXDR = horizonError.extras?.resultXDR,
                    let error = errorFromResponse(resultXDR: resultXDR) {
                    throw error
                }

                do {
                    let txResponse = try JSONDecoder().decode(TransactionResponse.self,
                                                              from: data)

                    return Promise<String>(txResponse.hash)
                }
                catch {
                    throw error
                }
        }
    }
}
