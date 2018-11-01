//
//  Endpoint.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

protocol EndpointProtocol {
    var base: URL { get }
    var url: URL { get }
    var params: [String: Any] { get }
}

extension EndpointProtocol {
    var url: URL {
        var p: String = params.isEmpty ? "" : "?"
        params.forEach({
            p += "\($0.key)=\($0.value)"
        })

        return base.appendingPathComponent(p, isDirectory: false)
    }
}

struct Endpoint: EndpointProtocol {
    let base: URL
    let params: [String: Any]

    init(_ base: URL) {
        self.base = base
        params = [:]
    }
}

struct AccountEndpoint: EndpointProtocol {
    let base: URL
    let params: [String: Any]
}

struct PaymentsEndpoint: EndpointProtocol {
    let base: URL
    let params: [String: Any]
}

struct TransactionsEndpoint: EndpointProtocol {
    let base: URL
    let params: [String: Any]
}

struct LedgersEndpoint: EndpointProtocol {
    let base: URL
    let params: [String: Any]

    enum Order: String {
        case ascending = "asc"
        case descending = "desc"
    }
}

struct CursorEndpoint: EndpointProtocol {
    let base: URL
    let params: [String: Any]
}

extension Endpoint {
    func account(_ account: String?) -> AccountEndpoint {
        let b = account != nil
            ? base.appendingPathComponent("accounts").appendingPathComponent(account!, isDirectory: false)
            : base

        return AccountEndpoint(base: b, params: params)
    }

    func payments() -> PaymentsEndpoint {
        return StellarKit.payments(url: base, params: params)
    }

    func transactions() -> TransactionsEndpoint {
        return StellarKit.transactions(url: base, params: params)
    }

    func ledgers() -> LedgersEndpoint {
        return StellarKit.ledgders(url: base, params: params)
    }
}

extension AccountEndpoint {
    func payments() -> PaymentsEndpoint {
        return StellarKit.payments(url: base, params: params)
    }

    func transactions() -> TransactionsEndpoint {
        return StellarKit.transactions(url: base, params: params)
    }
}

extension PaymentsEndpoint {
    func cursor(_ cursor: String?) -> CursorEndpoint {
        return StellarKit.cursor(url: base, cursor: cursor)
    }
}

extension TransactionsEndpoint {
    func cursor(_ cursor: String?) -> CursorEndpoint {
        return StellarKit.cursor(url: base, cursor: cursor)
    }
}

extension LedgersEndpoint {
    func order(_ order: Order) -> LedgersEndpoint {
        let p = parameterFixup(url: url, parameter: "?order=\(order.rawValue)")
        return LedgersEndpoint(base: url.appendingPathComponent(p), params: [:])
    }

    func limit(_ limit: Int) -> LedgersEndpoint {
        let p = parameterFixup(url: url, parameter: "?limit=\(limit)")
        return LedgersEndpoint(base: url.appendingPathComponent(p), params: [:])
    }
}

//MARK: -

private func payments(url: URL, params: [String: Any]) -> PaymentsEndpoint {
    return PaymentsEndpoint(base: url.appendingPathComponent("payments"), params: [:])
}

private func transactions(url: URL, params: [String: Any]) -> TransactionsEndpoint {
    return TransactionsEndpoint(base: url.appendingPathComponent("transactions"), params: [:])
}

private func ledgders(url: URL, params: [String: Any]) -> LedgersEndpoint {
    return LedgersEndpoint(base: url.appendingPathComponent("ledgers"), params: [:])
}

private func cursor(url: URL, cursor: String?) -> CursorEndpoint {
    if let cursor = cursor {
        return CursorEndpoint(base: URL(string: url.absoluteString + "?cursor=\(cursor)")!, params: [:])
    }

    return CursorEndpoint(base: url, params: [:])
}

private func parameterFixup(url: URL, parameter: String) -> String {
    if url.absoluteString.contains("?") && parameter.first == "?" {
        return String(parameter.suffix(parameter.count - 1))
    }

    return parameter
}
