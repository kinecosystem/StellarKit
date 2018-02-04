//
//  Promise.swift
//  StellarKit
//
//  Created by Avi Shevin on 30/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

public typealias ResultHandler = (Any) throws -> Any?
public typealias VoidResultHandler = (Any) throws -> Void
public typealias ErrorHandler = (Error) -> Void

public final class Promise {
    private var result: Any? = nil
    private var error: Error? = nil

    private var errorHandler: ErrorHandler?

    private var signaled: Bool {
        return result != nil || error != nil
    }

    private let waitGroup = DispatchGroup()
    private var finished = false

    public init() {
        waitGroup.enter()
    }

    public func signal(_ result: Any) {
        guard signaled == false else {
            return
        }

        self.result = result

        waitGroup.leave()
    }

    public func signal(_ error: Error) {
        guard signaled == false else {
            return
        }

        self.error = error

        waitGroup.leave()
    }

    @discardableResult
    public func then(_ handler: @escaping ResultHandler) -> Promise {
        if finished {
            return self
        }

        return commonThen { result -> Any? in
            let res: Any?

            do {
                res = try handler(result)
            }
            catch {
                res = error
            }

            return res
        }
    }

    @discardableResult
    public func then(_ handler: @escaping VoidResultHandler) -> Promise {
        if finished {
            return self
        }

        return commonThen { result -> Any? in
            var res: Any? = nil

            do {
                try handler(result)
            }
            catch {
                res = error
            }

            return res
        }
    }

    public func error(_ handler: @escaping ErrorHandler) {
        if let error = error {
            handler(error)
        }
        else {
            errorHandler = handler
        }
    }

    private func commonThen(handler: ResultHandler) -> Promise {
        waitGroup.wait()

        finished = true

        if let result = result {
            var res: Any? = nil

            do {
                res = try handler(result)
            }
            catch {
                res = error
            }

            if let promise = res as? Promise {
                return promise
            }
            else if let error = res as? Error {
                self.error = error
                errorHandler?(error)
            }
        }
        else if let error = error {
            errorHandler?(error)
        }

        return self
    }
}
