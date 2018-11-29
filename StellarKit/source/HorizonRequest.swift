//
// JSONRequest.swift
// StellarKit
//
// Created by Kin Foundation.
// Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import KinUtil

class HorizonRequest: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    private var session: URLSession
    private var task: URLSessionDataTask
    fileprivate var data = Data()

    fileprivate var completion: ((Data?, Error?) -> ())?

    override init() {
        session = URLSession()
        task = URLSessionDataTask()

        super.init()

        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    private struct E: Error { let horizonError: HorizonResponses.HorizonError }

    func load<T: Decodable>(url: URL) -> Promise<T> {
        let p = Promise<T>()

        task = session.dataTask(with: url)
        task.resume()

        completion = { data, error in
            if let error = error {
                p.signal(error)
            }

            if let e = try? JSONDecoder().decode(HorizonResponses.HorizonError.self, from: data!) {
                p.signal(e)
            }
            else {
                do {
                    p.signal(try JSONDecoder().decode(T.self, from: data!))
                }
                catch {
                    p.signal(error)
                }
            }
        }

        return p
    }

    deinit {
        print("bye")
    }
}

extension HorizonRequest {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        completion?(self.data, error)
        completion = nil

        session.finishTasksAndInvalidate()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.data.append(data)
    }
}

extension EP.AccountsEndpoint {
    public func load(from base: URL) -> Promise<HorizonResponses.AccountDetails> {
        return HorizonRequest().load(url: url(with: base))
    }
}

extension EP.LedgersEndpoint {
    public func load(from base: URL) -> Promise<HorizonResponses.Ledgers> {
        return HorizonRequest().load(url: url(with: base))
    }

    public func load(from base: URL) -> Promise<HorizonResponses.Ledger> {
        return HorizonRequest().load(url: url(with: base))
    }
}

extension EP.TransactionsEndpoint {
    public func load(from base: URL) -> Promise<HorizonResponses.Transactions> {
        return HorizonRequest().load(url: url(with: base))
    }

    public func load(from base: URL) -> Promise<HorizonResponses.Transaction> {
        return HorizonRequest().load(url: url(with: base))
    }
}
