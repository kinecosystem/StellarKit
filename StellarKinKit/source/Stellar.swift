//
//  Stellar.swift
//  StellarKinKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

public protocol Account {
    var publicKey: String? { get }

    func sign(message: Data, passphrase: String) throws -> Data
}

public typealias Completion = (String?, Error?) -> Void

public class Stellar {
    typealias FLDW = FixedLengthDataWrapper

    public let baseURL: URL
    public let asset: Asset

    private let networkId: String

    // MARK: -

    public init(baseURL: URL,
                asset: Asset? = nil,
                networkId: String = "Test SDF Network ; September 2015") {
        self.baseURL = baseURL
        self.asset = asset ?? .ASSET_TYPE_NATIVE
        self.networkId = networkId
    }

    // MARK: -

    public func payment(source: Account,
                        destination: String,
                        amount: Int64,
                        passphrase: String,
                        asset: Asset? = nil,
                        completion: @escaping Completion) {
        balance(account: destination, asset: asset) { (balance, error) in
            if let error = error as? StellarError, case StellarError.missingBalance = error {
                completion(nil, StellarError.destinationNotReadyForAsset(asset ?? self.asset))

                return
            }

            let op = self.paymentOp(destination: destination,
                                    amount: amount,
                                    source: source,
                                    asset: asset)

            self.issueTransaction(source: source,
                                  passphrase: passphrase,
                                  operations: [op],
                                  completion: completion)
        }
    }

    public func trust(asset: Asset,
                      account: Account,
                      passphrase: String,
                      completion: @escaping Completion) {
        issueTransaction(source: account,
                         passphrase: passphrase,
                         operations: [trustOp(asset: asset)],
                         completion: completion)
    }

    public func balance(account: String,
                        asset: Asset? = nil,
                        completion: @escaping (Decimal?, Error?) -> Void) {
        let url = baseURL.appendingPathComponent("accounts").appendingPathComponent(account)

        URLSession
            .shared
            .dataTask(with: url, completionHandler: { (data, response, error) in
                if error != nil {
                    completion(nil, error)

                    return
                }

                guard
                    let d = data,
                    let jsonOpt = try? JSONSerialization.jsonObject(with: d,
                                                                    options: []) as? [String: Any],
                    let json = jsonOpt
                    else {
                        completion(nil, StellarError.parseError(data))

                        return
                }

                guard let balances = json["balances"] as? [[String: Any]] else {
                    completion(nil, StellarError.missingBalance)

                    return
                }

                for balance in balances {
                    if
                        let code = balance["asset_code"] as? String,
                        let issuer = balance["asset_issuer"] as? String,
                        let amountStr = balance["balance"] as? String,
                        let amount = Decimal(string: amountStr) {
                        if code == "native" || Asset(assetCode: code, issuer: issuer) == asset ?? self.asset {
                            completion(amount, nil)

                            return
                        }
                    }
                }

                completion(nil, StellarError.missingBalance)
            })
            .resume()
    }

    // This is for testing only.
    public func fund(account: String, completion: @escaping (Bool) -> Void) {
        let url = baseURL.appendingPathComponent("friendbot")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.query = "addr=\(account)"

        URLSession
            .shared
            .dataTask(with: comps.url!, completionHandler: { (data, response, error) in
                var success = true

                defer {
                    completion(success)
                }

                guard
                    let d = data,
                    let jsonOpt = try? JSONSerialization.jsonObject(with: d,
                                                                    options: []) as? [String: Any],
                    let json = jsonOpt
                    else {
                        success = false

                        return
                }

                if let errorResponse = errorFromResponse(response: json) as? CreateAccountError {
                    switch errorResponse {
                    case .CREATE_ACCOUNT_ALREADY_EXIST:
                        break
                    default:
                        success = false
                    }
                }
            })
            .resume()
    }

    // MARK: -

    public func createAccountOp(destination: String,
                                balance: Int64,
                                source: Account? = nil) -> Operation {
        let destPK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FLDW(KeyUtils.key(base32: destination)))

        var sourcePK: PublicKey? = nil
        if let source = source, let pk = source.publicKey {
            sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FLDW(KeyUtils.key(base32: pk)))
        }

        return Operation(sourceAccount: sourcePK,
                         body: Operation.Body.CREATE_ACCOUNT(CreateAccountOp(destination: destPK,
                                                                             balance: balance)))
    }

    public func paymentOp(destination: String,
                          amount: Int64,
                          source: Account? = nil,
                          asset: Asset? = nil) -> Operation {
        let destPK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FLDW(KeyUtils.key(base32: destination)))

        var sourcePK: PublicKey? = nil
        if let source = source, let pk = source.publicKey {
            sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FLDW(KeyUtils.key(base32: pk)))
        }

        return Operation(sourceAccount: sourcePK,
                         body: Operation.Body.PAYMENT(PaymentOp(destination: destPK,
                                                                asset: asset ?? self.asset,
                                                                amount: amount)))

    }

    public func trustOp(source: Account? = nil, asset: Asset? = nil) -> Operation {
        var sourcePK: PublicKey? = nil
        if let source = source, let pk = source.publicKey {
            sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FLDW(KeyUtils.key(base32: pk)))
        }

        return Operation(sourceAccount: sourcePK,
                         body: Operation.Body.CHANGE_TRUST(ChangeTrustOp(asset: asset ?? self.asset)))
    }

    // MARK: -

    public func transaction(source: Account,
                            operations: [Operation],
                            sequence: UInt64 = 0,
                            completion: @escaping (Transaction?, Error?) -> Void) {
        guard let sourceKey = source.publicKey else {
            completion(nil, StellarError.missingPublicKey)

            return
        }

        let sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FLDW(KeyUtils.key(base32: sourceKey)))

        let comp = { (sequence: UInt64) -> Void in
            let tx = Transaction(sourceAccount: sourcePK,
                                 seqNum: sequence,
                                 timeBounds: nil,
                                 memo: .MEMO_NONE,
                                 operations: operations)

            completion(tx, nil)
        }

        if sequence > 0 {
            comp(sequence)

            return
        }

        self.sequence(account: sourceKey) { sequence, error in
            guard error == nil else {
                completion(nil, error)

                return
            }

            guard let sequence = sequence else {
                completion(nil, StellarError.missingSequence)

                return
            }

            comp(sequence + 1)
        }
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

    public func sequence(account: String, completion: @escaping (UInt64?, Error?) -> Void) {
        let url = baseURL.appendingPathComponent("accounts").appendingPathComponent(account)

        URLSession
            .shared
            .dataTask(with: url, completionHandler: { (data, response, error) in
                if error != nil {
                    completion(nil, error)

                    return
                }

                guard
                    let d = data,
                    let jsonOpt = try? JSONSerialization.jsonObject(with: d,
                                                                    options: []) as? [String: Any],
                    let json = jsonOpt else {
                        completion(nil, StellarError.parseError(data))

                        return
                }

                guard
                    let sequenceStr = json["sequence"] as? String,
                    let sequence = UInt64(sequenceStr) else {
                        completion(nil, StellarError.missingSequence)

                        return
                }

                completion(sequence, nil)
            })
            .resume()
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

        let payload = TransactionSignaturePayload(networkId: FLDW(networkId),
                                                  taggedTransaction: .ENVELOPE_TYPE_TX(tx))

        let message = payload.toXDR().sha256

        let signature = try signer.sign(message: message, passphrase: passphrase)

        return TransactionEnvelope(tx: tx,
                                   signatures: [DecoratedSignature(hint: FLDW(hint),
                                                                   signature: signature)])
    }

    private func issueTransaction(source: Account,
                                  passphrase: String,
                                  operations: [Operation],
                                  completion: @escaping Completion) {
        self.transaction(source: source,
                         operations: operations,
                         completion: { tx, error in
                            guard error == nil else {
                                completion(nil, error)

                                return
                            }

                            guard let tx = tx else {
                                completion(nil, StellarError.unknownError(nil))

                                return
                            }

                            do {
                                let envelope = try self.sign(transaction: tx,
                                                             signer: source,
                                                             passphrase: passphrase)

                                self.postTransaction(envelope: envelope, completion: completion)
                            }
                            catch {
                                completion(nil, error)
                            }
        })
    }

    private func postTransaction(envelope: TransactionEnvelope, completion: @escaping Completion) {
        guard let urlEncodedEnvelope = envelope.toXDR().base64EncodedString().urlEncoded else {
            completion(nil, StellarError.urlEncodingFailed)

            return
        }

        let url = baseURL.appendingPathComponent("transactions")

        guard let httpBody = ("tx=" + urlEncodedEnvelope).data(using: .utf8) else {
            completion(nil, StellarError.dataEncodingFailed)

            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = httpBody

        URLSession
            .shared
            .dataTask(with: request, completionHandler: { data, response, error in
                if error != nil {
                    completion(nil, error)

                    return
                }

                guard
                    let d = data,
                    let jsonOpt = try? JSONSerialization.jsonObject(with: d,
                                                                    options: []) as? [String: Any],
                    let json = jsonOpt
                    else {
                        completion(nil, StellarError.parseError(data))

                        return
                }

                if let resultError = errorFromResponse(response: json) {
                    completion(nil, resultError)

                    return
                }

                guard let hash = json["hash"] as? String else {
                    completion(nil, StellarError.missingHash)

                    return
                }

                completion(hash, nil)
            })
            .resume()
    }
}
