//
//  Endpoint.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

protocol EndpointProtocol {
    var url: URL { get }
}

struct Endpoint: EndpointProtocol {
    let url: URL
}

struct AccountEndpoint: EndpointProtocol {
    let url: URL
}

struct PaymentsEndpoint: EndpointProtocol {
    let url: URL
}

struct TransactionsEndpoint: EndpointProtocol {
    let url: URL
}

struct CursorEndpoint: EndpointProtocol {
    let url: URL
}

extension Endpoint {
    func account(_ account: String?) -> AccountEndpoint {
        if let account = account {
            return AccountEndpoint(url: url.appendingPathComponent("accounts").appendingPathComponent(account))
        }

        return AccountEndpoint(url: url)
    }

    func payments() -> PaymentsEndpoint {
        return StellarKit.payments(url: url)
    }

    func transactions() -> TransactionsEndpoint {
        return StellarKit.transactions(url: url)
    }
}

extension AccountEndpoint {
    func payments() -> PaymentsEndpoint {
        return StellarKit.payments(url: url)
    }

    func transactions() -> TransactionsEndpoint {
        return StellarKit.transactions(url: url)
    }
}

extension PaymentsEndpoint {
    func cursor(_ cursor: String?) -> CursorEndpoint {
        return StellarKit.cursor(url: url, cursor: cursor)
    }
}

extension TransactionsEndpoint {
    func cursor(_ cursor: String?) -> CursorEndpoint {
        return StellarKit.cursor(url: url, cursor: cursor)
    }
}

//MARK: -

private func payments(url: URL) -> PaymentsEndpoint {
    return PaymentsEndpoint(url: url.appendingPathComponent("payments"))
}

private func transactions(url: URL) -> TransactionsEndpoint {
    return TransactionsEndpoint(url: url.appendingPathComponent("transactions"))
}

private func cursor(url: URL, cursor: String?) -> CursorEndpoint {
    if let cursor = cursor {
        return CursorEndpoint(url: URL(string: url.absoluteString + "?cursor=\(cursor)")!)
    }

    return CursorEndpoint(url: url)
}
