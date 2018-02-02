//
//  Stellar.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

public protocol Account {
    var publicKey: String? { get }

    func sign(message: Data, passphrase: String) throws -> Data
}

/**
 `Stellar` provides an API for communicating with Stellar Horizon servers, with an emphasis on
 supporting non-native assets.
 */
public class Stellar {
    typealias WD32 = WrappedData32

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
     - parameter passphrase: The passphrase which will unlock the secret key of the sender.
     - parameter asset: The `Asset` to be sent.  Defaults to the `Asset` specified in the initializer.

     - Returns: A promise which will be signalled with the result of the operation.
     */
    public func payment(source: Account,
                        destination: String,
                        amount: Int64,
                        passphrase: String,
                        asset: Asset? = nil) -> Promise {
        return balance(account: destination, asset: asset)
            .then { _ -> Promise in
                let op = self.paymentOp(destination: destination,
                                        amount: amount,
                                        source: nil,
                                        asset: asset)

                return self.issueTransaction(source: source,
                                             passphrase: passphrase,
                                             operations: [op])
        }
    }

    /**
     Establishes trust for a non-native asset.

     - parameter asset: The `Asset` to trust.
     - parameter account: The `Account` which will trust the given asset.
     - parameter passphrase: The passphrase which will unlock the secret key of the trusting account.

     - Returns: A promise which will be signalled with the result of the operation.
     */
    public func trust(asset: Asset, account: Account, passphrase: String) -> Promise {
        let p = Promise()

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

                self.issueTransaction(source: account,
                                      passphrase: passphrase,
                                      operations: [self.trustOp(asset: asset)])
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
    public func balance(account: String, asset: Asset? = nil) -> Promise {
        let p = Promise()

        let url = baseURL.appendingPathComponent("accounts").appendingPathComponent(account)

        URLSession
            .shared
            .dataTask(with: url, completionHandler: { (data, response, error) in
                if let error = error {
                    p.signal(error)

                    return
                }

                do {
                    let json = try self.json(from: data)

                    guard let balances = json["balances"] as? [[String: Any]] else {
                        p.signal(StellarError.missingAccount)

                        return
                    }

                    let asset = asset ?? self.asset

                    for balance in balances {
                        if
                            let code = balance["asset_code"] as? String,
                            let amountStr = balance["balance"] as? String,
                            let amount = Decimal(string: amountStr) {
                            let issuer = balance["asset_issuer"] as? String ?? ""
                            if (code == "native" && asset.assetCode == "native") ||
                                Asset(assetCode: code, issuer: issuer) == asset {
                                p.signal(amount)

                                return
                            }
                        }
                    }

                    p.signal(StellarError.missingBalance)
                }
                catch {
                    p.signal(error)
                }
            })
            .resume()

        return p
    }

    // This is for testing only.
    // The account used for funding exists only on test-net.
    /// :nodoc:
    public func fund(account: String) -> Promise {
        let funderPK = "GBSJ7KFU2NXACVHVN2VWQIXIV5FWH6A7OIDDTEUYTCJYGY3FJMYIDTU7"
        let funderSK = "SAXSDD5YEU6GMTJ5IHA6K35VZHXFVPV6IHMWYAQPSEKJRNC5LGMUQX35"

        let sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: funderPK)))

        return self.sequence(account: funderPK)
            .then { sequence -> Any in
                guard let sequence = sequence as? UInt64 else {
                    return StellarError.internalInconsistency
                }

                let tx = Transaction(sourceAccount: sourcePK,
                                     seqNum: sequence + 1,
                                     timeBounds: nil,
                                     memo: .MEMO_NONE,
                                     operations: [self.createAccountOp(destination: account,
                                                                       balance: 10 * 10000000)])

                let envelope = try self.sign(transaction: tx,
                                             signer: StellarAccount(publicKey: funderPK,
                                                                    secretKey: funderSK),
                                             passphrase: "")

                return self.postTransaction(envelope: envelope)
        }
    }

    // MARK: -

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

    // MARK: -

    public func transaction(source: Account,
                            operations: [Operation],
                            sequence: UInt64 = 0) -> Promise {
        let p = Promise()

        guard let sourceKey = source.publicKey else {
            p.signal(StellarError.missingPublicKey)

            return p
        }

        let sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: sourceKey)))

        let comp = { (sequence: UInt64) -> Void in
            let tx = Transaction(sourceAccount: sourcePK,
                                 seqNum: sequence,
                                 timeBounds: nil,
                                 memo: .MEMO_NONE,
                                 operations: operations)

            p.signal(tx)
        }

        if sequence > 0 {
            comp(sequence)

            return p
        }

        self.sequence(account: sourceKey)
            .then { sequence -> Void in
                guard let sequence = sequence as? UInt64 else {
                    throw StellarError.internalInconsistency
                }

                comp(sequence + 1)
            }
            .error { error in
                p.signal(StellarError.missingSequence)
        }

        return p
    }

    public func sign(transaction tx: Transaction,
                     signer: Account,
                     passphrase: String) throws -> TransactionEnvelope {
        guard let publicKey = signer.publicKey else {
            throw StellarError.missingPublicKey
        }

        return try sign(transaction: tx,
                        signer: signer,
                        passphrase: passphrase,
                        hint: KeyUtils.key(base32: publicKey).suffix(4))
    }

    public func sequence(account: String) -> Promise {
        let p = Promise()

        let url = baseURL.appendingPathComponent("accounts").appendingPathComponent(account)

        URLSession
            .shared
            .dataTask(with: url, completionHandler: { (data, response, error) in
                if let error = error {
                    p.signal(error)

                    return
                }

                do {
                    let json = try self.json(from: data)

                    guard
                        let sequenceStr = json["sequence"] as? String,
                        let sequence = UInt64(sequenceStr) else {
                            p.signal(StellarError.missingSequence)

                            return
                    }

                    p.signal(sequence)
                }
                catch {
                    p.signal(error)
                }
            })
            .resume()

        return p
    }

    //MARK: -

    private func sign(transaction tx: Transaction,
                      signer: Account,
                      passphrase: String,
                      hint: Data) throws -> TransactionEnvelope {
        guard let data = self.networkId.data(using: .utf8) else {
            throw StellarError.dataEncodingFailed
        }

        let networkId = data.sha256

        let payload = TransactionSignaturePayload(networkId: WD32(networkId),
                                                  taggedTransaction: .ENVELOPE_TYPE_TX(tx))

        let message = try Data(bytes: XDREncoder.encode(payload)).sha256

        let signature = try signer.sign(message: message, passphrase: passphrase)

        return TransactionEnvelope(tx: tx,
                                   signatures: [DecoratedSignature(hint: WrappedData4(hint),
                                                                   signature: signature)])
    }

    private func issueTransaction(source: Account,
                                  passphrase: String,
                                  operations: [Operation]) -> Promise {
        return self.transaction(source: source,operations: operations)
            .then { tx -> Any in
                guard let tx = tx as? Transaction else {
                    return StellarError.internalInconsistency
                }

                let envelope = try self.sign(transaction: tx,
                                             signer: source,
                                             passphrase: passphrase)

                return self.postTransaction(envelope: envelope)
            }
    }

    private func postTransaction(envelope: TransactionEnvelope) -> Promise {
        let p = Promise()

        do {
            let envelopeData = try Data(XDREncoder.encode(envelope))
            guard let urlEncodedEnvelope = envelopeData.base64EncodedString().urlEncoded else {
                p.signal(StellarError.urlEncodingFailed)

                return p
            }

            let url = baseURL.appendingPathComponent("transactions")

            guard let httpBody = ("tx=" + urlEncodedEnvelope).data(using: .utf8) else {
                p.signal(StellarError.dataEncodingFailed)

                return p
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = httpBody

            URLSession
                .shared
                .dataTask(with: request, completionHandler: { data, response, error in
                    if let error = error {
                        p.signal(error)
                        
                        return
                    }

                    do {
                        let json = try self.json(from: data)

                        if let resultError = errorFromResponse(response: json) {
                            p.signal(resultError)

                            return
                        }

                        guard let hash = json["hash"] as? String else {
                            p.signal(StellarError.missingHash)

                            return
                        }

                        p.signal(hash)
                    }
                    catch {
                        p.signal(error)
                    }
                })
                .resume()

            return p
        }
        catch {
            p.signal(error)

            return p
        }
    }

    private func json(from data: Data?) throws -> [String: Any] {
        guard let d = data,
            let jsonOpt = try? JSONSerialization.jsonObject(with: d,
                                                            options: []) as? [String: Any],
            let json = jsonOpt
            else {
                throw StellarError.parseError(data)
        }

        return json
    }
}

// This is for testing only.
/// :nodoc:
private struct StellarAccount: Account {
    var publicKey: String?
    var secretKey: String

    func sign(message: Data, passphrase: String) throws -> Data {
        guard let keyPair = KeyUtils.keyPair(from: secretKey) else {
            throw StellarError.unknownError(nil)
        }

        return try KeyUtils.sign(message: message,
                                 signingKey: keyPair.secretKey)
    }
}
