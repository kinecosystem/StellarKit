//
//  Stellar.swift
//  StellarKinKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import Sodium

public typealias Completion = (String?, Error?) -> Void

public class Stellar {
    private let baseURL: URL
    private let kinAsset: Asset
    private let kinIssuer: String

    public init(baseURL: URL, kinIssuer: String = "GBGFNADX2FTYVCLDCVFY5ZRTVEMS4LV6HKMWOY7XJKVXMBIWVDESCJW5") {
        self.baseURL = baseURL
        self.kinIssuer = kinIssuer

        let kinAssetPK = PublicKey
            .PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(Data(base32KeyToData(key: kinIssuer))))

        self.kinAsset = Asset
            .ASSET_TYPE_CREDIT_ALPHANUM4(Asset
                .Alpha4(assetCode: FixedLengthDataWrapper("KIN\0".data(using: .utf8)!),
                        issuer: kinAssetPK))
    }

    public func payment(source: StellarAccount,
                        destination: String,
                        amount: Int64,
                        passphrase: String,
                        completion: @escaping Completion) {
        balance(account: destination) { (balance, error) in
            if let error = error as? StellarError {
                switch error {
                case .missingBalance:
                    completion(nil, StellarError.destinationNotReadyForKIN)

                    return

                default:
                    break
                }
            }

            guard let sourceKey = source.publicKey else {
                completion(nil, StellarError.missingPublicKey)

                return
            }

            guard let secretKey = source.secretKey(passphrase: passphrase) else {
                completion(nil, StellarError.missingSecretKey)

                return
            }

            let destinationData = KeyUtils.key(base32: destination)

            self.issueOperation(source: KeyUtils.key(base32: sourceKey),
                                operation: self.paymentOp(destination: destinationData,
                                                          amount: amount),
                                signingKey: secretKey,
                                completion: completion)

        }
    }

    public func trustKIN(account: StellarAccount,
                         passphrase: String,
                         completion: @escaping Completion) {
        guard let sourceKey = account.publicKey else {
            completion(nil, StellarError.missingPublicKey)

            return
        }

        guard let secretKey = account.secretKey(passphrase: passphrase) else {
            completion(nil, StellarError.missingSecretKey)

            return
        }

        issueOperation(source: KeyUtils.key(base32: sourceKey),
                       operation: trustOp(),
                       signingKey: secretKey,
                       completion: completion)
    }

    public func balance(account: String, completion: @escaping (Decimal?, Error?) -> Void) {
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
                    if balance["asset_code"] as? String == "KIN" &&
                        balance["asset_issuer"] as? String == self.kinIssuer {
                        if let amountStr = balance["balance"] as? String, let amount = Decimal(string: amountStr) {
                            completion(amount, nil)

                            return
                        }
                    }
                }

                completion(nil, StellarError.missingBalance)
            })
            .resume()
    }

    public func trustTransaction(account: StellarAccount,
                                 passphrase: String,
                                 completion: @escaping (Data?, Error?) -> Void) {
        guard let sourceKey = account.publicKey else {
            completion(nil, StellarError.missingPublicKey)

            return
        }

        guard let secretKey = account.secretKey(passphrase: passphrase) else {
            completion(nil, StellarError.missingSecretKey)

            return
        }

        createTransaction(source: KeyUtils.key(base32: sourceKey),
                          operation: trustOp(),
                          signingKey: secretKey) { (envelope, error) in
                            guard error == nil else {
                                completion(nil, error)

                                return
                            }

                            completion(envelope?.toXDR(), nil)
        }
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

    private func createTransaction(source: Data,
                                   operation: Operation,
                                   signingKey: Data,
                                   completion: @escaping (TransactionEnvelope?, Error?) -> Void) {
        sequence(account: source) { sequence, error in
            guard error == nil else {
                completion(nil, error)

                return
            }

            guard let sequence = sequence else {
                completion(nil, StellarError.missingSequence)

                return
            }

            do {
                let envelope = try self.txEnvelope(source: source,
                                                   sequence: sequence,
                                                   operation: operation,
                                                   signingKey: signingKey)

                completion(envelope, nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    private func issueOperation(source: Data, operation: Operation, signingKey: Data, completion: @escaping Completion) {
        createTransaction(source: source,
                          operation: operation,
                          signingKey: signingKey) { (envelope, error) in
                            guard error == nil else {
                                completion(nil, error)

                                return
                            }

                            if let envelope = envelope {
                                self.postTransaction(envelope: envelope, completion: completion)
                            }
        }
    }

    private func sequence(account: Data, completion: @escaping (UInt64?, Error?) -> Void) {
        let base32 = publicKeyToBase32(account)
        let url = baseURL.appendingPathComponent("accounts").appendingPathComponent(base32)

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

    private func paymentOp(destination: Data, amount: Int64) -> Operation {
        let destPK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(destination))

        return Operation(sourceAccount: nil,
                         body: Operation.Body.PAYMENT(PaymentOp(destination: destPK,
                                                                asset: self.kinAsset,
                                                                amount: amount)))

    }

    private func trustOp() -> Operation {
        return Operation(sourceAccount: nil,
                         body: Operation.Body.CHANGE_TRUST(ChangeTrustOp(asset: self.kinAsset)))
    }

    private func txEnvelope(source: Data,
                            sequence: UInt64,
                            operation: Operation,
                            signingKey: Data) throws -> TransactionEnvelope {
        let sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(source))

        let tx = Transaction(sourceAccount: sourcePK,
                             seqNum: sequence + 1,
                             timeBounds: nil,
                             memo: .MEMO_NONE,
                             operations: [
                                operation,
                                ])

        return try sign(transaction: tx, signingKey: signingKey, hint: source.suffix(4))
    }

    private func sign(transaction tx: Transaction,
                      signingKey: Data,
                      hint: Data) throws -> TransactionEnvelope {
        guard let data = "Test SDF Network ; September 2015".data(using: .utf8) else {
            throw StellarError.dataEncodingFailed
        }

        let networkId = data.sha256

        let payload = TransactionSignaturePayload(networkId: FixedLengthDataWrapper(networkId),
                                                  taggedTransaction: .ENVELOPE_TYPE_TX(tx))

        let sodium = Sodium()

        let message = payload.toXDR().sha256
        guard let signature = sodium.sign.signature(message: message, secretKey: signingKey) else {
            throw StellarError.signingFailed
        }

        return TransactionEnvelope(tx: tx,
                                   signatures: [DecoratedSignature(hint: FixedLengthDataWrapper(hint),
                                                                   signature: signature)])
    }
}
