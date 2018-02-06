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
                        asset: Asset? = nil) -> Promise<String> {
        return balance(account: destination, asset: asset)
            .then { _ in
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
    public func trust(asset: Asset, account: Account, passphrase: String) -> Promise<String> {
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

    // This is for testing only.
    // The account used for funding exists only on test-net.
    /// :nodoc:
    public func fund(account: String) -> Promise<String> {
        let funderPK = "GBSJ7KFU2NXACVHVN2VWQIXIV5FWH6A7OIDDTEUYTCJYGY3FJMYIDTU7"
        let funderSK = "SAXSDD5YEU6GMTJ5IHA6K35VZHXFVPV6IHMWYAQPSEKJRNC5LGMUQX35"

        let sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: funderPK)))

        return self.sequence(account: funderPK)
            .then { sequence in
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
                            sequence: UInt64 = 0) -> Promise<Transaction> {
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
                                 memo: .MEMO_NONE,
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

    public func sequence(account: String) -> Promise<UInt64> {
        return accountDetails(account: account)
            .then { accountDetails in
                let p = Promise<UInt64>()

                return p.signal(accountDetails.seqNum)
        }
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
                                  operations: [Operation]) -> Promise<String> {
        return self.transaction(source: source,operations: operations)
            .then { tx in
                let envelope = try self.sign(transaction: tx,
                                             signer: source,
                                             passphrase: passphrase)

                return self.postTransaction(envelope: envelope)
            }
    }

    private func postTransaction(envelope: TransactionEnvelope) -> Promise<String> {
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

    private func accountDetails(account: String) -> Promise<AccountDetails> {
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

    private func issue(request: URLRequest) -> Promise<Data> {
        let p = Promise<Data>()

        URLSession
            .shared
            .dataTask(with: request, completionHandler: { (data, response, error) in
                if let error = error {
                    p.signal(error)

                    return
                }

                guard let data = data else {
                    p.signal(StellarError.internalInconsistency)

                    return
                }

                p.signal(data)
            })
            .resume()

        return p
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
