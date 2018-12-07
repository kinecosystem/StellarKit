//
//  Endpoint.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import KinUtil

private func url(for components: [EP], and options: Set<Option>, with base: URL) -> URL {
    var path = ""

    for component in components {
        switch component {
        case .accounts(let account):
            path += "accounts/\(account)"
        case .ledgers(let num):
            path += (path.isEmpty ? "" : "/") + "ledgers" + (num != nil ? "/\(num!)" : "")
        case .operations(let num):
            path += (path.isEmpty ? "" : "/") + "operations" + (num != nil ? "/\(num!)" : "")
        case .payments:
            path += (path.isEmpty ? "" : "/") + "payments"
        case .transactions(let id):
            path += (path.isEmpty ? "" : "/") + "transactions" + (id != nil ? "/\(id!)" : "")
        }
    }

    var params = options.isEmpty ? "" : "?"
    for option in options {
        switch option {
        case .order(let order):
            params += (params.count == 1 ? "" : "&") + "order=\(order.rawValue)"
        case .limit(let limit):
            params += (params.count == 1 ? "" : "&") + "limit=\(limit)"
        case .cursor(let cursor):
            params += (params.count == 1 ? "" : "&") + "cursor=\(cursor)"
        case .null:
            break
        }
    }

    return URL(string: "\(base.absoluteString)/\(path)\(params)")!
}

enum Option: Hashable {
    enum Order: String { case asc, desc }

    case order(Order)
    case limit(Int)
    case cursor(String)
    case null
}

protocol CollectionQueryable {
    var options: Set<Option> { get }

    func order(_ order: Option.Order) -> Self
    func limit(_ limit: Int) -> Self
    func cursor(_ cursor: String?) -> Self
}

protocol EndpointProtocol {
    var components: [EP] { get }

    func url(with base: URL) -> URL
}

protocol SimpleEndpoint: EndpointProtocol { }

extension SimpleEndpoint {
    func url(with base: URL) -> URL {
        return StellarKit.url(for: components, and: [], with: base)
    }
}

protocol CollectionEndpoint: SimpleEndpoint, CollectionQueryable {
    init(_ eps: [EP], options: Set<Option>)
}

extension CollectionEndpoint {
    func url(with base: URL) -> URL {
        return StellarKit.url(for: components, and: options, with: base)
    }
}

extension CollectionEndpoint {
    func order(_ order: Option.Order) -> Self {
        return Self.init(components, options: options.union([Option.order(order)]))
    }

    func limit(_ limit: Int) -> Self {
        return Self.init(components, options: options.union([Option.limit(limit)]))
    }

    func cursor(_ cursor: String?) -> Self {
        return Self.init(components,
                         options: options.union([cursor != nil ? Option.cursor(cursor!) : .null]))
    }
}

protocol ContainsTxComponents: SimpleEndpoint { }

extension ContainsTxComponents {
    func operations() -> EP.OperationsEndpoint {
        return EP.OperationsEndpoint(components, options: [])
    }

    func payments() -> EP.PaymentsEndpoint {
        return EP.PaymentsEndpoint(components, options: [])
    }

    func transactions() -> EP.TransactionsEndpoint {
        return EP.TransactionsEndpoint(components, options: [])
    }
}

enum EP {
    case accounts(String)
    case ledgers(Int?)
    case operations(Int?)
    case payments
    case transactions(String?)

    struct AccountEndpoint: SimpleEndpoint, ContainsTxComponents {
        let components: [EP]

        init(account: String) {
            components = [.accounts(account)]
        }
    }

    struct LedgerEndpoint: SimpleEndpoint, ContainsTxComponents {
        let components: [EP]

        init(ledger: Int) {
            components = [.ledgers(ledger)]
        }
    }

    struct LedgersEndpoint: CollectionEndpoint {
        let components: [EP]
        let options: Set<Option>

        init(_ eps: [EP], options: Set<Option>) {
            components = eps + (options.isEmpty ? [.ledgers(nil)] : [])
            self.options = options
        }
    }

    struct OperationEndpoint: SimpleEndpoint {
        let components: [EP]

        init(operation: Int) {
            components = [.operations(operation)]
        }
    }

    struct OperationsEndpoint: CollectionEndpoint {
        let components: [EP]
        let options: Set<Option>

        init(_ eps: [EP], options: Set<Option>) {
            components = eps + (options.isEmpty ? [.operations(nil)] : [])
            self.options = options
        }
    }

    struct PaymentsEndpoint: CollectionEndpoint {
        let components: [EP]
        let options: Set<Option>

        init(_ eps: [EP], options: Set<Option>) {
            components = eps + (options.isEmpty ? [.payments] : [])
            self.options = options
        }
    }

    struct TransactionEndpoint: SimpleEndpoint {
        let components: [EP]

        init(transaction: String) {
            components = [.transactions(transaction)]
        }

        func operations() -> OperationsEndpoint {
            return EP.OperationsEndpoint(components, options: [])
        }

        func payments() -> PaymentsEndpoint {
            return EP.PaymentsEndpoint(components, options: [])
        }
    }

    struct TransactionsEndpoint: CollectionEndpoint {
        let components: [EP]
        let options: Set<Option>

        init(_ eps: [EP], options: Set<Option>) {
            components = eps + (options.isEmpty ? [.transactions(nil)] : [])
            self.options = options
        }
    }
}

enum Endpoint {
    static func account(_ account: String) -> EP.AccountEndpoint {
        return EP.AccountEndpoint(account: account)
    }

    static func ledger(_ ledger: Int) -> EP.LedgerEndpoint {
        return EP.LedgerEndpoint(ledger: ledger)
    }

    static func ledgers() -> EP.LedgersEndpoint {
        return EP.LedgersEndpoint([], options: [])
    }

    static func operation(_ operation: Int) -> EP.OperationEndpoint {
        return EP.OperationEndpoint(operation: operation)
    }

    static func operations() -> EP.OperationsEndpoint {
        return EP.OperationsEndpoint([], options: [])
    }

    static func payments() -> EP.PaymentsEndpoint {
        return EP.PaymentsEndpoint([], options: [])
    }

    static func transaction(_ transaction: String) -> EP.TransactionEndpoint {
        return EP.TransactionEndpoint(transaction: transaction)
    }

    static func transactions() -> EP.TransactionsEndpoint {
        return EP.TransactionsEndpoint([], options: [])
    }
}
