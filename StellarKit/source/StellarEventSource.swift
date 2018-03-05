//
//  StellarEventSource.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import KinUtil

public class StellarEventSource: NSObject, URLSessionDataDelegate {
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

    private var onMessageCallback: ((_ id: String?, _ event: String?, _ data: String?) -> Void)?

    init(url: URL) {
        self.url = url
        self.emitter = Observable<Event>()

        super.init()

        connect()
    }

    func connect() {
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

    func onMessage(_ callback: @escaping ((_ id: String?, _ event: String?, _ data: String?) -> Void)) {
        onMessageCallback = callback
    }

    var lineEnding = ""
    var stringQueue = [String]()
    var stringAccumulator = ""

    func determineLineEnding(_ string: String) {
        let cr = string.contains("\r")
        let lf = string.contains("\n")

        lineEnding = cr
            ? (lf ? "\r\n" : "\r")
            : (lf ? "\n" : "")
    }

    func extractLines() {
        guard lineEnding != "" else {
            return
        }

        while let location = stringAccumulator.range(of: lineEnding)?.lowerBound {
            stringQueue.append(String(stringAccumulator[..<location]))
            stringAccumulator = stringAccumulator.substring(from: stringAccumulator.index(after: location))
        }
    }

    func extractEvents() -> [[String]] {
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

    func parse(_ event: [String]) -> (String?, String?, String?) {
        var id: String?
        var eventName: String?
        var data: String?

        for string in event {
            if string.hasPrefix(":") {
                continue
            }

            if let location = string.range(of: ":")?.lowerBound {
                let key = String(string[..<location])
                let val = String(string[string.index(after: location)..<string.endIndex])

                #if swift(>=4.0)
                    var value = val
                #else
                    guard var value = val else {
                    continue
                    }
                #endif

                value = value.hasPrefix(" ") ? String(value.dropFirst()) : value

                switch key {
                case "id": id = val
                case "event": eventName = val
                case "data": data = value
                case "retry": retryTime = Int(value) ?? retryTime
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
                    onMessageCallback?(id, eventName, data)
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

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard state != .closed else {
            return
        }

        let code = (error as NSError?)?.code

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
