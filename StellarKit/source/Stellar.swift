//
//  Stellar.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import KinUtil

public enum NetworkId {
    private static let testId = "Test SDF Network ; September 2015"
    private static let mainId = "Public Global Stellar Network ; September 2015"

    case main
    case test
    case custom(String)
}

extension NetworkId: CustomStringConvertible {
    public var description: String {
        switch self {
        case .main: return NetworkId.mainId
        case .test: return NetworkId.testId
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

public struct Node {
    public let baseURL: URL
    public let networkId: NetworkId

    public init(baseURL: URL, networkId: NetworkId = .test) {
        self.baseURL = baseURL
        self.networkId = networkId
    }
}

extension Node {
    public func networkConfiguration() -> Promise<NetworkConfiguration> {
        return Endpoint.ledgers().order(.desc).limit(1).load(from: baseURL)
            .then({ (response: Responses.Ledgers) -> Promise<NetworkConfiguration> in
                return Promise(NetworkConfiguration(response))
            })
    }

    /**
     Observe transactions on the given node.

     - parameter lastEventId: If non-`nil`, only transactions with a later event Id will be observed.
     A value of **"now"** will only observe transactions completed after observation begins.

     - Returns: An instance of `TxWatch`, which contains an `Observable` which emits `TxInfo` objects.
     */
    public func txWatch(lastEventId: String?) -> EventWatcher<TxEvent> {
        let url = Endpoint.transactions().cursor(lastEventId).url(with: baseURL)

        return EventWatcher(eventSource: StellarEventSource(url: url))
    }

    /**
     Observe payments on the given node.

     - parameter lastEventId: If non-`nil`, only payments with a later event Id will be observed.
     A value of **"now"** will only observe payments completed after observation begins.

     - Returns: An instance of `EventWatcher`, which contains an `Observable` which emits `PaymentEvent` objects.
     */
    public func paymentWatch(lastEventId: String?) -> EventWatcher<PaymentEvent> {
        let url = Endpoint.payments().cursor(lastEventId).url(with: baseURL)

        return EventWatcher(eventSource: StellarEventSource(url: url))
    }

    public func post(envelope: TransactionEnvelope) -> Promise<Responses.TransactionSuccess> {
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

        var request = URLRequest(url: Endpoint.transactions().url(with: baseURL))
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

public protocol Account {
    var publicKey: String { get }
    
    var sign: ((Data) throws -> [UInt8])? { get }

    init(publicKey: String)
}

extension Account {
    public func accountDetails(node: Node) -> Promise<Responses.AccountDetails> {
        return Endpoint.account(publicKey).load(from: node.baseURL)
            .mapError({
                if let error = $0 as? Responses.RequestFailure, error.status == 404 {
                    return StellarError.missingAccount
                }

                return $0
            })
    }

    public func sequence(seqNum: UInt64 = 0, node: Node) -> Promise<UInt64> {
        if seqNum > 0 {
            return Promise().signal(seqNum)
        }

        return accountDetails(node: node)
            .then { return Promise<UInt64>().signal($0.seqNum + 1) }
    }

    public func balance(asset: Asset = .ASSET_TYPE_NATIVE, node: Node) -> Promise<Decimal> {
        return accountDetails(node: node)
            .then({ accountDetails -> Decimal in
                for balance in accountDetails.balances where balance.asset == asset {
                    return balance.balanceNum
                }

                throw StellarError.missingBalance
            })
    }

    /**
     Observe transactions for the account on the given node.

     - parameter lastEventId: If non-`nil`, only transactions with a later event Id will be observed.
     A value of **"now"** will only observe transactions completed after observation begins.
     - parameter node: An object describing the network endpoint.

     - Returns: An instance of `EventWatcher`, which contains an `Observable` which emits `TxEvent` objects.
     */
    public func txWatch(lastEventId: String?, node: Node) -> EventWatcher<TxEvent> {
        let url = Endpoint.account(publicKey)
            .transactions()
            .cursor(lastEventId)
            .url(with: node.baseURL)

        return EventWatcher(eventSource: StellarEventSource(url: url))
    }

    /**
     Observe payments for the account on the given node.

     - parameter lastEventId: If non-`nil`, only payments with a later event Id will be observed.
     A value of **"now"** will only observe payments completed after observation begins.
     - parameter node: An object describing the network endpoint.

     - Returns: An instance of `EventWatcher`, which contains an `Observable` which emits `PaymentEvent` objects.
     */
    public func paymentWatch(lastEventId: String?, node: Node) -> EventWatcher<PaymentEvent> {
        let url = Endpoint.account(publicKey)
            .payments()
            .cursor(lastEventId)
            .url(with: node.baseURL)

        return EventWatcher(eventSource: StellarEventSource(url: url))
    }
}

extension Transaction {
    public func sign(using account: Account, for node: Node) throws -> DecoratedSignature {
        guard let signer = account.sign else { throw StellarError.missingSignClosure }

        let sig = try signer(self.hash(networkId: String(describing: node.networkId)))

        let hint = WrappedData4(KeyUtils.key(base32: account.publicKey).suffix(4))

        return DecoratedSignature(hint: hint, signature: sig)
    }
}
