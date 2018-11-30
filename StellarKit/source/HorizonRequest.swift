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
    fileprivate class RequestState {
        var data: Data
        var completion: (Data?, Error?) -> ()

        init(data: Data, completion: @escaping (Data?, Error?) -> ()) {
            self.data = data
            self.completion = completion
        }
    }

    private var session: URLSession
    fileprivate var tasks = [URLSessionTask: RequestState]()

    override init() {
        session = URLSession()

        super.init()

        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 10_000

        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    private struct E: Error { let horizonError: HorizonResponses.HorizonError }

    func load<T: Decodable>(url: URL) -> Promise<T> {
        let p = Promise<T>()

        let task = session.dataTask(with: url)

        let completion: (Data?, Error?) -> () = { data, error in
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

        tasks[task] = RequestState(data: Data(), completion: completion)

        task.resume()

        return p
    }

    func post(request: URLRequest) -> Promise<Data> {
        let p = Promise<Data>()

        let task = session.dataTask(with: request)

        let completion: (Data?, Error?) -> () = { data, error in
            if let error = error {
                p.signal(error)
            }

            if let data = data {
                p.signal(data)
            }
        }

        tasks[task] = RequestState(data: Data(), completion: completion)

        task.resume()

        return p
    }
}

extension HorizonRequest {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let state = tasks[task] {
            state.completion(state.data, error)
            tasks[task] = nil
        }

        session.finishTasksAndInvalidate()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        tasks[dataTask]?.data.append(data)
    }
}

extension EP.AccountsEndpoint {
    public func load(from base: URL, using: HorizonRequest? = nil) -> Promise<HorizonResponses.AccountDetails> {
        return (using ?? HorizonRequest()).load(url: url(with: base))
    }
}

extension EP.LedgersEndpoint {
    public func load(from base: URL, using: HorizonRequest? = nil) -> Promise<HorizonResponses.Ledgers> {
        return (using ?? HorizonRequest()).load(url: url(with: base))
    }

    public func load(from base: URL, using: HorizonRequest? = nil) -> Promise<HorizonResponses.Ledger> {
        return (using ?? HorizonRequest()).load(url: url(with: base))
    }
}

extension EP.TransactionsEndpoint {
    public func load(from base: URL, using: HorizonRequest? = nil) -> Promise<HorizonResponses.Transactions> {
        return (using ?? HorizonRequest()).load(url: url(with: base))
    }

    public func load(from base: URL, using: HorizonRequest? = nil) -> Promise<HorizonResponses.Transaction> {
        return (using ?? HorizonRequest()).load(url: url(with: base))
    }
}
