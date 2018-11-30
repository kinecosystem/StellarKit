//
//  Endpoint.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import KinUtil

enum Option: Hashable {
    enum Order: String { case asc, desc }

    case order(Order)
    case limit(Int)
    case cursor(String)
}

protocol EndpointProtocol {
    var components: [EP] { get }
    var options: Set<Option> { get }

    func url(with base: URL) -> URL

    init(_ eps: [EP], options: Set<Option>)

    func order(_ order: Option.Order) -> Self
    func limit(_ limit: Int) -> Self
    func cursor(_ cursor: String?) -> Self
}

extension EndpointProtocol {
    func url(with base: URL) -> URL {
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
            }
        }

        return URL(string: "\(base.absoluteString)/\(path)\(params)")!
    }
}

extension EndpointProtocol {
    func order(_ order: Option.Order) -> Self {
        return Self.init(components, options: options.union([Option.order(order)]))
    }

    func limit(_ limit: Int) -> Self {
        return Self.init(components, options: options.union([Option.limit(limit)]))
    }

    func cursor(_ cursor: String?) -> Self {
        return Self.init(components,
                         options: cursor != nil ? options.union([Option.cursor(cursor!)]) : options)
    }
}

enum EP {
    case accounts(String)
    case ledgers(Int?)
    case operations(Int?)
    case payments
    case transactions(String?)

    struct AccountsEndpoint: EndpointProtocol {
        let components: [EP]
        let options: Set<Option> = Set()

        init(_ eps: [EP], options: Set<Option>) {
            fatalError("account must be first")
        }

        init(account: String?) {
            components = account != nil ? [.accounts(account!)] : []
        }

        func operations() -> OperationsEndpoint {
            return EP.OperationsEndpoint(components, options: options)
        }

        func payments() -> PaymentsEndpoint {
            return EP.PaymentsEndpoint(components, options: options)
        }

        func transactions() -> TransactionsEndpoint {
            return EP.TransactionsEndpoint(components, options: options)
        }
    }

    struct LedgersEndpoint: EndpointProtocol {
        let components: [EP]
        let options: Set<Option>

        init(_ eps: [EP], options: Set<Option>) {
            components = eps + (options.isEmpty ? [.ledgers(nil)] : [])
            self.options = options
        }

        init(ledger: Int?) {
            components = [.ledgers(ledger)]
            options = Set()
        }

        func operations() -> OperationsEndpoint {
            return EP.OperationsEndpoint(components, options: options)
        }

        func payments() -> PaymentsEndpoint {
            return EP.PaymentsEndpoint(components, options: options)
        }

        func transactions() -> TransactionsEndpoint {
            return EP.TransactionsEndpoint(components, options: options)
        }
    }

    struct OperationsEndpoint: EndpointProtocol {
        let components: [EP]
        let options: Set<Option>

        init(_ eps: [EP], options: Set<Option>) {
            components = eps + (options.isEmpty ? [.operations(nil)] : [])
            self.options = options
        }

        init(operation: Int?) {
            components = [.operations(operation)]
            options = Set()
        }
    }

    struct PaymentsEndpoint: EndpointProtocol {
        let components: [EP]
        let options: Set<Option>

        init(_ eps: [EP], options: Set<Option>) {
            components = eps + (options.isEmpty ? [.payments] : [])
            self.options = options
        }
    }

    struct TransactionsEndpoint: EndpointProtocol {
        let components: [EP]
        let options: Set<Option>

        init(_ eps: [EP], options: Set<Option>) {
            components = eps + (options.isEmpty ? [.transactions(nil)] : [])
            self.options = options
        }

        init(transaction: String?) {
            components = [.transactions(transaction)]
            options = Set()
        }

        func operations() -> EndpointProtocol {
            return EP.OperationsEndpoint(components, options: options)
        }

        func payments() -> EndpointProtocol {
            return EP.PaymentsEndpoint(components, options: options)
        }
    }
}

enum Endpoint {
    static func accounts(_ account: String?) -> EP.AccountsEndpoint {
        return EP.AccountsEndpoint(account: account)
    }

    static func ledgers(_ ledger: Int? = nil) -> EP.LedgersEndpoint {
        return EP.LedgersEndpoint(ledger: ledger)
    }

    static func operations(_ operation: Int? = nil) -> EP.OperationsEndpoint {
        return EP.OperationsEndpoint(operation: operation)
    }

    static func payments() -> EP.PaymentsEndpoint {
        return EP.PaymentsEndpoint([], options: Set())
    }

    static func transactions(_ transaction: String? = nil) -> EP.TransactionsEndpoint {
        return EP.TransactionsEndpoint(transaction: transaction)
    }
}
