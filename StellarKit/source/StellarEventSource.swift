//
//  StellarEventSource.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import KinUtil
import Dispatch

public final class StellarEventSource: NSObject, URLSessionDataDelegate {
    private enum State {
        case connecting
        case open
        case closed
    }

    public struct Event {
        let id: String?
        let event: String?
        let data: String?
    }

    private let url: URL

    private var state = State.connecting

    private var urlSession: URLSession?
    private var task: URLSessionDataTask?
    private var retryTime = 3000

    public private(set) var lastEventId: String?

    public private(set) var emitter: Observable<Event>!

    public init(url: URL) {
        self.url = url
        self.emitter = Observable<Event>()

        super.init()

        connect()
    }

    private func connect() {
        guard state != .closed else {
            return
        }

        var headers: [String: String] = [
            "Accept": "text/event-stream",
            "Cache-Control": "no-cache",
        ]

        if let lastEventId = lastEventId {
            headers["Last-Event-Id"] = lastEventId
        }

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = headers

        config.timeoutIntervalForRequest = TimeInterval(Int32.max)
        config.timeoutIntervalForResource = TimeInterval(Int32.max)

        urlSession = URLSession(configuration: config,
                                delegate: self,
                                delegateQueue: OperationQueue())

        task = urlSession?.dataTask(with: url)

        task?.resume()
    }

    public func close() {
        state = .closed

        emitter?.finish()

        task?.cancel()
        urlSession?.invalidateAndCancel()
        urlSession = nil
        emitter = nil
    }

    private var lineEnding = ""
    private var stringQueue = [String]()
    private var stringAccumulator = ""

    private func determineLineEnding(_ string: String) {
        let cr = string.contains("\r")
        let lf = string.contains("\n")

        lineEnding = cr
            ? (lf ? "\r\n" : "\r")
            : (lf ? "\n" : "")
    }

    private func extractLines() {
        guard lineEnding != "" else {
            return
        }

        while let location = stringAccumulator.range(of: lineEnding)?.lowerBound {
            let s: Substring = stringAccumulator[..<location]
            stringQueue.append(String(s))
            stringAccumulator = stringAccumulator.substring(from: stringAccumulator.index(after: location))
        }
    }

    private func extractEvents() -> [[String]] {
        var events = [[String]]()
        var event = [String]()

        let queue = stringQueue

        for string in queue {
            if string == "" {
                stringQueue.removeSubrange(0...event.count)

                events.append(event)
                event = [String]()
            }
            else {
                event.append(string)
            }
        }

        return events
    }

    private func parse(_ event: [String]) -> (String?, String?, String?) {
        var id: String?
        var eventName: String?
        var data: String?

        for string in event {
            if string.hasPrefix(":") {
                continue
            }

            let parts = string.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                let key = String(parts[0])
                var val = String(parts[1])

                val = val.hasPrefix(" ") ? String(val.dropFirst()) : val

                switch key {
                case "id": id = val
                case "event": eventName = val
                case "data": data = val
                case "retry": retryTime = Int(val) ?? retryTime
                default: break
                }

                eventName = eventName ?? "message"
            }
        }

        lastEventId = id ?? lastEventId

        return (id, eventName, data)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard state == .open else {
            return
        }

        if let string = String(bytes: data, encoding: .utf8) {
            if lineEnding == "" {
                determineLineEnding(string)
            }

            stringAccumulator += string

            extractLines()

            for event in extractEvents() {
                let (id, eventName, data) = parse(event)

                if eventName == "message" {
                    emitter?.next(Event(id: id, event: eventName, data: data))
                }
            }
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(.allow)

        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200: state = .open
            case 204: close()
            default: break
            }
        }
    }

    #if os(Linux)
    public typealias TaskError = NSError
    #else
    public typealias TaskError = Error
    #endif

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: TaskError?) {
        guard state != .closed else {
            return
        }

        #if os(Linux)
            let code = error?.code
        #else
            let code = (error as NSError?)?.code
        #endif

        if error == nil || code != -999 {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(retryTime / 1000)) {
                self.connect()
            }
        }
        else {
            emitter.finish()
        }
    }
}
