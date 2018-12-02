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
    public var description: String {
        switch self {
        case .test: return testId
        case .main: return mainId
        case .custom(let identifier): return identifier
        }
    }
}

public struct NetworkConfiguration {
    let baseFee: UInt32
    let baseReserve: UInt32
    let maxTxSetSize: Int

    init(_ ledgers: Responses.Ledgers) {
        baseFee = ledgers.ledgers[0].baseFee
        baseReserve = ledgers.ledgers[0].baseReserve
        maxTxSetSize = ledgers.ledgers[0].max_tx_set_size
    }
}

/**
 `Stellar` provides an API for communicating with Stellar Horizon servers.
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
     Obtain the balance for a given asset.
     
     - parameter account: The `Account` whose balance will be retrieved.
     - parameter asset: The `Asset` whose balance will be obtained.
     - parameter node: An object describing the network endpoint.
     
     - Returns: A promise which will be signalled with the result of the operation.
     */
    public static func balance(account: String,
                               asset: Asset = .ASSET_TYPE_NATIVE,
                               node: Node) -> Promise<Decimal> {
        return accountDetails(account: account, node: node)
            .then({ accountDetails -> Decimal in
                for balance in accountDetails.balances where balance.asset == asset {
                    return balance.balanceNum
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
    public static func accountDetails(account: String, node: Node) -> Promise<Responses.AccountDetails> {
        return Endpoint.accounts(account).load(from: node.baseURL)
            .mapError({
                if let error = $0 as? Responses.RequestFailure, error.status == 404 {
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

    public static func networkConfiguration(node: Node) -> Promise<NetworkConfiguration> {
        return Endpoint.ledgers().order(.desc).limit(1).load(from: node.baseURL)
            .then({ (response: Responses.Ledgers) -> Promise<NetworkConfiguration> in
                return Promise(NetworkConfiguration(response))
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
    
    public static func postTransaction(envelope: TransactionEnvelope, node: Node) -> Promise<Responses.TransactionSuccess> {
        let envelopeData: Data
        do {
            envelopeData = try Data(XDREncoder.encode(envelope))
        }
        catch {
            return Promise(error)
        }
        
        guard let urlEncodedEnvelope = envelopeData.base64EncodedString().urlEncoded else {
            return Promise(StellarError.urlEncodingFailed)
        }
        
        guard let httpBody = ("tx=" + urlEncodedEnvelope).data(using: .utf8) else {
            return Promise(StellarError.dataEncodingFailed)
        }
        
        var request = URLRequest(url: Endpoint.transactions().url(with: node.baseURL))
        request.httpMethod = "POST"
        request.httpBody = httpBody

        return HorizonRequest().post(request: request)
            .then { data in
                if let failure = try? JSONDecoder().decode(Responses.RequestFailure.self, from: data) {
                    throw failure
                }
                
                let txResponse = try JSONDecoder().decode(Responses.TransactionSuccess.self,
                                                          from: data)
                return Promise(txResponse)
        }
    }
}
