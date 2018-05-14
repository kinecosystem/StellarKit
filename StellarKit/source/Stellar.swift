//
//  Stellar.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import StellarErrors
import KinUtil

public protocol Account {
    var publicKey: String? { get }
    
    var sign: ((Data) throws -> Data)? { get }
}

private let testId = "Test SDF Network ; September 2015"
private let mainId = "Public Global Stellar Network ; September 2015"

public enum NetworkId {
    case test
    case main
    case custom(String)
}

extension NetworkId: CustomStringConvertible {
    public init(_ description: String) {
        switch description {
        case testId: self = .test
        case mainId: self = .main
        default: self = .custom(description)
        }
    }
    
    public var description: String {
        switch self {
        case .test: return testId
        case .main: return mainId
        case .custom(let identifier): return identifier
        }
    }
}

/**
 `Stellar` provides an API for communicating with Stellar Horizon servers, with an emphasis on
 supporting non-native assets.
 */
public struct Stellar {
    public struct Node {
        public let baseURL: URL
        public let networkId: NetworkId
        
        public init(baseURL: URL, networkId: NetworkId = .test) {
            self.baseURL = baseURL
            self.networkId = networkId
        }
    }
    
    /**
     Sends a payment to the given account.
     
     - parameter source: The account from which the payment will be made.
     - parameter destination: The public key of the receiving account, as a base32 string.
     - parameter amount: The amount to be sent.
     - parameter asset: The `Asset` to be sent.  Defaults to the `Asset` specified in the initializer.
     - parameter memo: A short string placed in the MEMO field of the transaction.
     - parameter node: An object describing the network endpoint.
     
     - Returns: A promise which will be signalled with the result of the operation.
     */
    public static func payment(source: Account,
                               destination: String,
                               amount: Int64,
                               asset: Asset = .ASSET_TYPE_NATIVE,
                               memo: Memo = .MEMO_NONE,
                               node: Node) -> Promise<String> {
        return balance(account: destination, asset: asset, node: node)
            .then { _ -> Promise<Transaction> in
                let op = Operation.payment(destination: destination,
                                           amount: amount,
                                           asset: asset,
                                           source: source)
                
                return self.transaction(source: source, operations: [ op ], memo: memo, node: node)
            }
            .then { tx -> Promise<String> in
                let envelope = try self.sign(transaction: tx,
                                             signer: source,
                                             node: node)
                
                return self.postTransaction(envelope: envelope, node: node)
            }
            .transformError({ error -> Error in
                if case StellarError.missingAccount = error {
                    return StellarError
                        .destinationNotReadyForAsset(error, asset.assetCode)
                }
                
                if case StellarError.missingBalance = error {
                    return StellarError
                        .destinationNotReadyForAsset(error, asset.assetCode)
                }
                
                return error
            })
    }
    
    /**
     Establishes trust for a non-native asset.
     
     - parameter asset: The `Asset` to trust.
     - parameter account: The `Account` which will trust the given asset.
     - parameter node: An object describing the network endpoint.
     
     - Returns: A promise which will be signalled with the result of the operation.
     */
    public static func trust(asset: Asset,
                             account: Account,
                             node: Node) -> Promise<String> {
        let p = Promise<String>()
        
        guard let destination = account.publicKey else {
            p.signal(StellarError.missingPublicKey)
            
            return p
        }
        
        balance(account: destination, asset: asset, node: node)
            .then { _ -> Void in
                p.signal("-na-")
            }
            .error { error in
                if case StellarError.missingAccount = error {
                    p.signal(error)
                    
                    return
                }
                
                self.transaction(source: account,
                                 operations: [Operation.changeTrust(asset: asset)],
                                 node: node)
                    .then { tx -> Promise<String> in
                        let envelope = try self.sign(transaction: tx,
                                                     signer: account,
                                                     node: node)
                        
                        return self.postTransaction(envelope: envelope, node: node)
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
     - parameter node: An object describing the network endpoint.
     
     - Returns: A promise which will be signalled with the result of the operation.
     */
    public static func balance(account: String,
                               asset: Asset = .ASSET_TYPE_NATIVE,
                               node: Node) -> Promise<Decimal> {
        return accountDetails(account: account, node: node)
            .then { accountDetails in
                let p = Promise<Decimal>()
                
                for balance in accountDetails.balances {
                    let code = balance.assetCode
                    let issuer = balance.assetIssuer
                    
                    if (balance.assetType == "native" && asset.assetCode == "native") {
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
    
    /**
     Obtain details for the given account.
     
     - parameter account: The `Account` whose details will be retrieved.
     - parameter node: An object describing the network endpoint.
     
     - Returns: A promise which will be signalled with the result of the operation.
     */
    public static func accountDetails(account: String, node: Node) -> Promise<AccountDetails> {
        let url = Endpoint(url: node.baseURL).account(account).url
        
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
    
    /**
     Observe transactions on the given node.  When `account` is non-`nil`, observations are
     limited to transactions involving the given account.
     
     - parameter account: The `Account` whose transactions will be observed.  Optional.
     - parameter lastEventId: If non-`nil`, only transactions with a later event Id will be observed.
     The string _now_ will only observe transactions completed after observation begins.
     - parameter node: An object describing the network endpoint.
     
     - Returns: An instance of `TxWatch`, which contains an `Observable` which emits `TxInfo` objects.
     */
    public static func txWatch(account: String? = nil,
                               lastEventId: String?,
                               node: Node) -> TxWatch {
        let url = Endpoint(url: node.baseURL).account(account).transactions().cursor(lastEventId).url
        
        return TxWatch(eventSource: StellarEventSource(url: url))
    }
    
    /**
     Observe payments on the given node.  When `account` is non-`nil`, observations are
     limited to payments involving the given account.
     
     - parameter account: The `Account` whose payments will be observed.  Optional.
     - parameter lastEventId: If non-`nil`, only payments with a later event Id will be observed.
     The string _now_ will only observe payments made after observation begins.
     - parameter node: An object describing the network endpoint.
     
     - Returns: An instance of `PaymentWatch`, which contains an `Observable` which emits `PaymentEvent` objects.
     */
    public static func paymentWatch(account: String? = nil,
                                    lastEventId: String?,
                                    node: Node) -> PaymentWatch {
        let url = Endpoint(url: node.baseURL).account(account).payments().cursor(lastEventId).url
        
        return PaymentWatch(eventSource: StellarEventSource(url: url))
    }
    
    //MARK: -
    
    public static func sequence(account: String, seqNum: UInt64 = 0, node: Node) -> Promise<UInt64> {
        if seqNum > 0 {
            return Promise().signal(seqNum)
        }
        
        return accountDetails(account: account, node: node)
            .then { accountDetails in
                return Promise<UInt64>().signal(accountDetails.seqNum + 1)
        }
    }
    
    public static func transaction(source: Account,
                                   operations: [Operation],
                                   sequence: UInt64 = 0,
                                   memo: Memo = .MEMO_NONE,
                                   node: Node) -> Promise<Transaction> {
        let p = Promise<Transaction>()
        
        guard let sourceKey = source.publicKey else {
            p.signal(StellarError.missingPublicKey)
            
            return p
        }
        
        let sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: sourceKey)))
        
        self.sequence(account: sourceKey, seqNum: sequence, node: node)
            .then {
                let tx = Transaction(sourceAccount: sourcePK,
                                     seqNum: $0,
                                     timeBounds: nil,
                                     memo: memo,
                                     operations: operations)
                
                p.signal(tx)
            }
            .error { _ in
                p.signal(StellarError.missingSequence)
        }
        
        return p
    }
    
    public static func sign(transaction tx: Transaction,
                            signer: Account,
                            node: Node) throws -> TransactionEnvelope {
        guard let publicKey = signer.publicKey else {
            throw StellarError.missingPublicKey
        }
        
        return try StellarKit.sign(transaction: tx,
                                   signer: signer,
                                   hint: KeyUtils.key(base32: publicKey).suffix(4),
                                   networkId: node.networkId.description)
    }
    
    public static func postTransaction(envelope: TransactionEnvelope, node: Node) -> Promise<String> {
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
        
        var request = URLRequest(url: Endpoint(url: node.baseURL).transactions().url)
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
    
    //MARK: -
    
    @available(*, unavailable)
    private init() { }
}
