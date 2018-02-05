//
//  Promise.swift
//  StellarKit
//
//  Created by Avi Shevin on 30/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

public typealias ErrorHandler = (Error) -> Void

public final class Promise<Value> {
    public private(set) var result: Value? = nil
    public private(set) var error: Error? = nil

    private var errorHandler: ErrorHandler?

    private var signaled: Bool {
        return result != nil || error != nil
    }

    private let waitGroup = DispatchGroup()
    private var finished = false

    public init() {
        waitGroup.enter()
    }

    convenience public init(_ result: Value) {
        self.init()

        signal(result)
    }

    convenience public init(_ error: Error) {
        self.init()

        signal(error)
    }

    @discardableResult
    public func signal(_ result: Value) -> Promise<Value> {
        return commonSignal(result)
    }

    @discardableResult
    public func signal(_ error: Error) -> Promise<Value> {
        return commonSignal(error)
    }

    @discardableResult
    public func then<NewValue>(_ handler: @escaping (Value) throws -> Promise<NewValue>) -> Promise<NewValue> {
        if finished {
            let p = Promise<NewValue>()
            p.errorHandler = errorHandler
            p.error = error

            return p
        }

        waitGroup.wait()

        finished = true

        if let result = result {
            var res: Any? = nil

            do {
                res = try handler(result)
            }
            catch {
                self.error = error
            }

            if let promise = res as? Promise<NewValue> {
                return promise
            }
        }

        let p = Promise<NewValue>()
        if let error = error {
            p.errorHandler = errorHandler
            p.signal(error)
        }

        return p
    }

    @discardableResult
    public func then(_ handler: @escaping (Value) throws -> Void) -> Promise {
        if finished {
            return self
        }

        waitGroup.wait()

        finished = true

        if let result = result {
            do {
                try handler(result)
            }
            catch {
                self.error = error
            }
        }

        if let error = error {
            errorHandler?(error)
        }

        return self
    }

    public func error(_ handler: @escaping ErrorHandler) {
        if let error = error {
            handler(error)
        }
        else {
            errorHandler = handler
        }
    }

    private func commonSignal(_ value: Any) -> Promise<Value> {
        guard signaled == false else {
            return self
        }

        if let value = value as? Value {
            self.result = value
        }
        else if let error = value as? Error {
            self.error = error
        }

        waitGroup.leave()

        return self
    }
}
