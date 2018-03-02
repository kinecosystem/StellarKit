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

typealias WD32 = WrappedData32

/**
 `Stellar` provides an API for communicating with Stellar Horizon servers, with an emphasis on
 supporting non-native assets.
 */
public class Stellar {
    public let baseURL: URL
    public let asset: Asset

    private let networkId: String

    // MARK: -

    /**
     Instantiates an instance of `Stellar`.

     - parameter baseURL: The `URL` of the Horizon end-point to communicate with.
     - parameter asset: The asset which will be used by default.
     - parameter networkId: The identifier for the Stellar network.  The default is the test-net.
     */
    public init(baseURL: URL,
                asset: Asset? = nil,
                networkId: String = "Test SDF Network ; September 2015") {
        self.baseURL = baseURL
        self.asset = asset ?? .ASSET_TYPE_NATIVE
        self.networkId = networkId
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
                let op = self.paymentOp(destination: destination,
                                        amount: amount,
                                        source: nil,
                                        asset: asset)

                return self.transaction(source: source, operations: [ op ], memo: memo)
            }
            .then { tx -> Promise<String> in
                let envelope = try self.sign(transaction: tx,
                                             signer: source)

                return self.postTransaction(baseURL: self.baseURL, envelope: envelope)
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

                self.transaction(source: account, operations: [self.trustOp(asset: asset)])
                    .then { tx -> Promise<String> in
                        let envelope = try self.sign(transaction: tx,
                                                     signer: account)

                        return self.postTransaction(baseURL: self.baseURL, envelope: envelope)
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

    public func watch(account: String? = nil, lastEventId: String?) -> TxWatch {
        var url = baseURL

        if let account = account {
            url = url
                .appendingPathComponent("accounts")
                .appendingPathComponent(account)
        }

        url = url
            .appendingPathComponent("transactions")

        if let lastEventId = lastEventId {
            url = URL(string: url.absoluteString + "?cursor=\(lastEventId)")!
        }

        return TxWatch(eventSource: StellarEventSource(url: url))
    }

    public func accountDetails(account: String) -> Promise<AccountDetails> {
        let url = baseURL.appendingPathComponent("accounts").appendingPathComponent(account)

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
                                   networkId: networkId)
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

//MARK: - Operations

extension Stellar {
    public func createAccountOp(destination: String,
                                balance: Int64,
                                source: Account? = nil) -> Operation {
        let destPK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: destination)))

        var sourcePK: PublicKey? = nil
        if let source = source, let pk = source.publicKey {
            sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: pk)))
        }

        return Operation(sourceAccount: sourcePK,
                         body: Operation.Body.CREATE_ACCOUNT(CreateAccountOp(destination: destPK,
                                                                             balance: balance)))
    }

    public func paymentOp(destination: String,
                          amount: Int64,
                          source: Account? = nil,
                          asset: Asset? = nil) -> Operation {
        let destPK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: destination)))

        var sourcePK: PublicKey? = nil
        if let source = source, let pk = source.publicKey {
            sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: pk)))
        }

        return Operation(sourceAccount: sourcePK,
                         body: Operation.Body.PAYMENT(PaymentOp(destination: destPK,
                                                                asset: asset ?? self.asset,
                                                                amount: amount)))

    }

    public func trustOp(source: Account? = nil, asset: Asset? = nil) -> Operation {
        var sourcePK: PublicKey? = nil
        if let source = source, let pk = source.publicKey {
            sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: pk)))
        }

        return Operation(sourceAccount: sourcePK,
                         body: Operation.Body.CHANGE_TRUST(ChangeTrustOp(asset: asset ?? self.asset)))
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
