//
//  Promise.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

private enum Result<Value> {
    case value(Value)
    case error(Error)
}

public class Promise<Value> {
    private var callbacks = [((Result<Value>) -> Void)]()
    private var errorHandler: ((Error) -> Void)?
    private var errorTransform: ((Error) -> Error) = { return $0 }

    private var result: Result<Value>? {
        didSet {
            callbacks.forEach { c in result.map { c($0) } }

            if let result = result {
                switch result {
                case .value: break
                case .error(let error): errorHandler?(errorTransform(error))
                }

                errorHandler = nil
            }
        }
    }

    public init() {

    }

    public convenience init(_ value: Value) {
        self.init()

        result = .value(value)
    }

    public convenience init(_ error: Error) {
        self.init()

        result = .error(error)
    }

    @discardableResult
    public func signal(_ value: Value) -> Promise {
        result = .value(value)

        return self
    }

    @discardableResult
    public func signal(_ error: Error) -> Promise {
        result = .error(error)

        return self
    }

    private func observe(callback: @escaping (Result<Value>) -> Void) {
        callbacks.append(callback)

        result.map { callback($0) }
    }

    @discardableResult
    public func then(handler: @escaping (Value) throws -> Void) -> Promise {
        let p = Promise<Value>()
        p.errorTransform = errorTransform

        observe { result in
            switch result {
            case .value(let value):
                do {
                    try handler(value)
                }
                catch {
                    p.signal(error)
                }

            case .error(let error):
                p.signal(error)
            }
        }

        return p
    }

    @discardableResult
    public func then<NewValue>(handler: @escaping (Value) throws -> Promise<NewValue>) -> Promise<NewValue> {
        let p = Promise<NewValue>()
        p.errorTransform = errorTransform

        observe { result in
            switch result {
            case .value(let value):
                do {
                    let promise = try handler(value)

                    promise.observe { result in
                        switch result {
                        case .value(let value):
                            p.signal(value)
                        case .error(let error):
                            p.signal(error)
                        }
                    }
                }
                catch {
                    p.signal(error)
                }

            case .error(let error):
                p.signal(error)
            }
        }

        return p
    }

    public func transformError(handler: @escaping (Error) -> Error) -> Promise {
        errorTransform = handler

        return self
    }

    public func error(handler: @escaping (Error) -> Void) {
        if let result = result {
            switch result {
            case .value: break
            case .error(let error): handler(errorTransform(error))
            }

            return
        }

        errorHandler = handler
    }
}
