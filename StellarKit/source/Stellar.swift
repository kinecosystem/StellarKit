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
    
    var sign: ((Data) throws -> [UInt8])? { get }
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

public struct NetworkParameters {
    let baseFee: UInt32

    init(_ ledgers: HorizonResponses.Ledgers) {
        baseFee = ledgers.ledgers[0].baseFee
    }
}

/**
 `Stellar` provides an API for communicating with Stellar Horizon servers, with an emphasis on
 supporting non-native assets.
 */
public enum Stellar {
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
                               fee: UInt32? = nil,
                               memo: Memo = .MEMO_NONE,
                               node: Node) -> Promise<String> {
        return balance(account: destination, asset: asset, node: node)
            .then { _ -> Promise<TransactionEnvelope> in
                let op = Operation.payment(destination: destination,
                                           amount: amount,
                                           asset: asset,
                                           source: source)
                
                return TxBuilder(source: source, node: node)
                    .set(fee: fee)
                    .set(memo: memo)
                    .add(operation: op)
                    .envelope(networkId: node.networkId.description)
            }
            .then {
                return self.postTransaction(envelope: $0, node: node)
            }
            .mapError({ error -> Error in
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
        guard let destination = account.publicKey else {
            return Promise(StellarError.missingPublicKey)
        }
        
        let p = Promise<String>()

        balance(account: destination, asset: asset, node: node)
            .then { _ -> Void in
                p.signal("-na-")
            }
            .error { error in
                if case StellarError.missingAccount = error {
                    p.signal(error)
                    
                    return
                }

                TxBuilder(source: account, node: node)
                    .add(operation: Operation.changeTrust(asset: asset))
                    .tx()
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
     Burn an account.

     - Parameter balance: The given `Account`s current balance.
     - Parameter asset: The `Asset` to burn.
     - Parameter account: The `Account` which will be burned.
     - Parameter node: An object describing the network endpoint.

     - Returns: A transaction hash if burned. If the burn already took place, a 'bad auth' error will be returned.
     */
    public static func burn(balance: Int64,
                            asset: Asset,
                            account: Account,
                            node: Node) -> Promise<String> {
        return TxBuilder(source: account, node: node)
            .add(operation: Operation.changeTrust(asset: asset, limit: balance))
            .add(operation: Operation.setOptions(masterWeight: 0))
            .tx()
            .then { transaction -> Promise<String> in
                let envelope = try Stellar.sign(transaction: transaction, signer: account, node: node)

                return Stellar.postTransaction(envelope: envelope, node: node)
        }
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
            .then({ accountDetails -> Decimal in
                for balance in accountDetails.balances {
                    let code = balance.assetCode
                    let issuer = balance.assetIssuer
                    
                    if (balance.assetType == "native" && asset.assetCode == "native") {
                        return balance.balanceNum
                    }
                    
                    if let issuer = issuer, let code = code,
                        Asset(assetCode: code, issuer: issuer) == asset {
                        return balance.balanceNum
                    }
                }
                
                throw StellarError.missingBalance
            })
    }
    
    /**
     Obtain details for the given account.
     
     - parameter account: The `Account` whose details will be retrieved.
     - parameter node: An object describing the network endpoint.
     
     - Returns: A promise which will be signalled with the result of the operation.
     */
    public static func accountDetails(account: String, node: Node) -> Promise<HorizonResponses.AccountDetails> {
        return Endpoint.accounts(account).load(from: node.baseURL)
            .mapError({
                if let error = $0 as? HorizonResponses.HorizonError, error.status == 404 {
                    return StellarError.missingAccount
                }

                return StellarError.unknownError($0)
            })
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
                               node: Node) -> EventWatcher<TxEvent> {
        let url = Endpoint.accounts(account).transactions().cursor(lastEventId).url(with: node.baseURL)

        return EventWatcher(eventSource: StellarEventSource(url: url))
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
                                    node: Node) -> EventWatcher<PaymentEvent> {
        let url = Endpoint.accounts(account).payments().cursor(lastEventId).url(with: node.baseURL)

        return EventWatcher(eventSource: StellarEventSource(url: url))
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

    public static func networkParameters(node: Node) -> Promise<NetworkParameters> {
        return Endpoint.ledgers().order(.desc).limit(1).load(from: node.baseURL)
            .then({ (response: HorizonResponses.Ledgers) -> Promise<NetworkParameters> in
                return Promise<NetworkParameters>(NetworkParameters(response))
            })
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
        
        var request = URLRequest(url: Endpoint.transactions().url(with: node.baseURL))
        request.httpMethod = "POST"
        request.httpBody = httpBody

        return HorizonRequest().post(request: request)
            .then { data in
                if let horizonError = try? JSONDecoder().decode(HorizonResponses.HorizonError.self, from: data),
                    let resultXDR = horizonError.extras?.resultXDR,
                    let error = errorFromResponse(resultXDR: resultXDR) {
                    throw error
                }
                
                do {
                    let txResponse = try JSONDecoder().decode(HorizonResponses.TransactionPostResponse.self,
                                                              from: data)
                    
                    return Promise(txResponse.hash)
                }
                catch {
                    throw error
                }
        }
    }
}
