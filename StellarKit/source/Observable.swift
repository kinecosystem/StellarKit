//
//  Observable.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

public protocol Unlinkable {
    func unlink()
}

private protocol UnlinkableObserver: Unlinkable {
    var observerCount: Int { get }
    var parent: UnlinkableObserver? { get }
    func add(to linkBag: LinkBag)
}

public class LinkBag {
    private var links = [Unlinkable]()

    public func add(_ unlinkable: Unlinkable) {
        links.append(unlinkable)
    }

    public init() {

    }
    
    deinit {
        links.forEach { $0.unlink() }
    }
}

private struct Observer<Value> {
    private var nextHandler: ((Value) -> Void)?
    private var errorHandler: ((Error) -> Void)?
    private var finishHandler: (() -> Void)?
    private var queue: DispatchQueue?

    func next(_ value: Value) {
        enqueue { self.nextHandler?(value) }
    }

    func error(_ error: Error) {
        enqueue { self.errorHandler?(error) }
    }

    func finish() {
        enqueue { self.finishHandler?() }
    }

    private func enqueue(_ block: @escaping () -> Void) {
        if let queue = queue {
            queue.async(execute: block)
        }
        else {
            block()
        }
    }

    init(next: ((Value) -> Void)? = nil,
         error: ((Error) -> Void)? = nil,
         finish: (() -> Void)? = nil,
         queue: DispatchQueue?) {
        self.nextHandler = next
        self.errorHandler = error
        self.finishHandler = finish
        self.queue = queue
    }
}

public class PausableObserver<Value>: Observable<Value> {
    private let limit: Int
    private var buffer = [Value]()

    public var paused = false {
        didSet {
            if !paused && oldValue != paused {
                buffer.forEach { super.next($0) }
                buffer.removeAll()
            }
        }
    }

    public init(limit: Int) {
        self.limit = limit
    }

    private func add(_ value: Value) {
        buffer.append(value)

        while buffer.count > limit {
            buffer.remove(at: 0)
        }
    }

    override public func next(_ value: Value) {
        if paused {
            add(value)
        }
        else {
            super.next(value)
        }
    }
}

public class Observable<Value>: UnlinkableObserver {
    private enum State {
        case open
        case complete
        case error
    }

    private var observers = [Observer<Value>]()
    private var state = State.open
    fileprivate var parent: UnlinkableObserver?

    fileprivate var observerCount: Int {
        return observers.count
    }

    public func on(queue: DispatchQueue? = nil, next: @escaping (Value) -> Void) -> Observable<Value> {
        observers.append(Observer(next: next, queue: queue))

        return self
    }

    public func on(queue: DispatchQueue? = nil, error: @escaping (Error) -> Void) -> Observable<Value> {
        observers.append(Observer(error: error, queue: queue))

        return self
    }

    public func on(queue: DispatchQueue? = nil, finish: @escaping () -> Void) -> Observable<Value> {
        observers.append(Observer(finish: finish, queue: queue))

        return self
    }

    public func next(_ value: Value) {
        guard state == .open else {
            return
        }

        self.observers.forEach { $0.next(value) }
    }

    public func error(_ error: Error) {
        guard state == .open else {
            return
        }

        state = .error

        self.observers.forEach { $0.error(error) }
    }

    public func finish() {
        guard state == .open else {
            return
        }

        state = .complete

        self.observers.forEach { $0.finish() }
    }

    public init() {

    }
}

//MARK: - UnlinkableObserver -

extension Observable {
    public func unlink() {
        if let count = parent?.observerCount, count < 2 {
            parent?.unlink()
        }

        parent = nil
    }

    public func add(to linkBag: LinkBag) {
        linkBag.add(self)
    }
}

//MARK: - Operators -

extension Observable {
    public func accumulate(limit: Int) -> Observable<[Value]> {
        var buffer = [Value]()

        let observable = Observable<[Value]>()
        observable.parent = on(next: { (value) in
            buffer.append(value)

            while buffer.count > limit {
                buffer.remove(at: 0)
            }

            observable.next(buffer)
        })

        return observable
    }

    public func combine<OtherValue>(with other: Observable<OtherValue>) -> Observable<(Value?, OtherValue?)> {
        let observable = Observable<(Value?, OtherValue?)>()

        var myLatest: Value?
        var otherLatest: OtherValue?

        let observer =
            on(next: { value in
                myLatest = value

                observable.next((value, otherLatest))
            })

        let otherObserver = other.on(next: { value in
            otherLatest = value

            observable.next((myLatest, otherLatest))
        })

        otherObserver.parent = observer
        observable.parent = otherObserver

        return observable
    }

    public func debug(_ identifier: String? = nil) -> Observable<Value> {
        let observable = Observable<Value>()
        observable.parent =
            on(next: { (value) -> Void in
                print("\(identifier ?? "Observable"): DEBUG: \(value)")

                observable.next(value)
            })

        return observable
    }

    public func filter(_ handler: @escaping (Value) -> Bool) -> Observable<Value> {
        let observable = Observable<Value>()
        observable.parent =
            on(next: { value in
                if handler(value) {
                    observable.next(value)
                }
            })

        return observable
    }

    public func flatMap<NewValue>(_ handler: @escaping (Value) -> NewValue?) -> Observable<NewValue> {
        let observable = Observable<NewValue>()
        observable.parent =
            on(next: { value in
                guard let value = handler(value) else {
                    return
                }

                observable.next(value)
            })

        return observable
    }

    public func map<NewValue>(_ handler: @escaping (Value) -> NewValue) -> Observable<NewValue> {
        let observable = Observable<NewValue>()
        observable.parent =
            on(next: { value in
                observable.next(handler(value))
            })

        return observable
    }

    public func pausable(limit: Int) -> PausableObserver<Value> {
        let observer = PausableObserver<Value>(limit: limit)
        observer.parent = self.on(next: { observer.next($0) })

        return observer
    }
}
