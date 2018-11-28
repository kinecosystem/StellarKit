//
//  Endpoint.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

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

    func order(_ order: Option.Order) -> EndpointProtocol
    func limit(_ limit: Int) -> EndpointProtocol
    func cursor(_ cursor: String?) -> EndpointProtocol
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
            case .transactions(let num):
                path += (path.isEmpty ? "" : "/") + "transactions" + (num != nil ? "/\(num!)" : "")
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
    func order(_ order: Option.Order) -> EndpointProtocol {
        return Self.init(components, options: options.union([Option.order(order)]))
    }

    func limit(_ limit: Int) -> EndpointProtocol {
        return Self.init(components, options: options.union([Option.limit(limit)]))
    }

    func cursor(_ cursor: String?) -> EndpointProtocol {
        return Self.init(components,
                         options: cursor != nil ? options.union([Option.cursor(cursor!)]) : options)
    }
}

enum EP {
    case accounts(String)
    case ledgers(Int?)
    case operations(Int?)
    case payments
    case transactions(Int?)

    struct AccountsEndpoint: EndpointProtocol {
        let components: [EP]
        let options: Set<Option> = Set()

        init(_ eps: [EP], options: Set<Option>) {
            components = eps + [.accounts("")]
        }

        init(account: String?) {
            components = account != nil ? [.accounts(account!)] : []
        }

        func operations() -> EndpointProtocol {
            return EP.OperationsEndpoint(components, options: options)
        }

        func payments() -> EndpointProtocol {
            return EP.PaymentsEndpoint(components, options: options)
        }

        func transactions() -> EndpointProtocol {
            return EP.TransactionsEndpoint(components, options: options)
        }
    }

    struct LedgersEndpoint: EndpointProtocol {
        let components: [EP]
        let options: Set<Option>

        init(_ eps: [EP], options: Set<Option>) {
            components = eps + [.ledgers(nil)]
            self.options = options
        }

        init(ledger: Int?) {
            components = [.ledgers(ledger)]
            options = Set()
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

        init(transaction: Int?) {
            components = [.transactions(transaction)]
            options = Set()
        }
    }
}

enum EndPoint {
    static func accounts(_ account: String?) -> EP.AccountsEndpoint {
        return EP.AccountsEndpoint(account: account)
    }

    static func ledgers(_ ledger: Int? = nil) -> EndpointProtocol {
        return EP.LedgersEndpoint(ledger: ledger)
    }

    static func operations(_ operation: Int? = nil) -> EndpointProtocol {
        return EP.OperationsEndpoint(operation: operation)
    }

    static func payments() -> EndpointProtocol {
        return EP.PaymentsEndpoint([], options: Set())
    }

    static func transactions(_ transaction: Int? = nil) -> EndpointProtocol {
        return EP.TransactionsEndpoint(transaction: transaction)
    }
}
