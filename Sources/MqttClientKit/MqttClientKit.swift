//
//  MqttClientKit.swift
//  Paintjet Foreman
//
//  Created by Jed Lu on 2025/7/15.
//

import ComposableArchitecture
import Foundation
import MQTTNIO
import NIOCore

public typealias Topic = String

public struct MqttClientKitInfo {
    public var address: String
    public var port: Int
    public var clientID: String

    public init(address: String, port: Int, clientID: String) {
        self.address = address
        self.port = port
        self.clientID = clientID
    }
}

enum MqttClientKitError: LocalizedError, Equatable {
    case timeout
    case closeUnexpect
    case noConnection
    case underlying(Swift.Error)

    var errorDescription: String? {
        switch self {
        case .timeout:
            "Connection Timeout"
        case .closeUnexpect:
            "Connection Closed Unexpectedly"
        case .underlying:
            "Underlying Error"
        case .noConnection:
            "No Connection"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .timeout:
            "Check if the device's Wi-Fi is connected to the router."
        case .closeUnexpect:
            "Ensure the device stays online during the connection process."
        case .noConnection:
            "No connection"
        case .underlying(let error):
            "\(error.localizedDescription)"
        }
    }

    static func == (lhs: MqttClientKitError, rhs: MqttClientKitError) -> Bool {
        switch (lhs, rhs) {
        case (.timeout, .timeout),
             (.closeUnexpect, .closeUnexpect),
             (.noConnection, .noConnection):
            true
        case (.underlying(let lhsError), .underlying(let rhsError)):
            lhsError.localizedDescription == rhsError.localizedDescription
        default:
            false
        }
    }
}

public struct MqttClientKit {
    @CasePathable
    enum State: Equatable {
        case idle
        case connected
        case connecting
        case disconnected(MqttClientKitError)
    }

    var connect: (MqttClientKitInfo) async -> AsyncStream<State>
    var disconnect: () async throws -> ()
    var publish: (MQTTPublishInfo) async throws -> ()
    var subscribe: (MQTTSubscribeInfo) async throws -> MQTTSuback?
    var unsubscribe: (Topic) async throws -> ()
    var isActive: () throws -> Bool
    var received: () -> AsyncThrowingStream<MQTTPublishInfo, Error>
}

extension DependencyValues {
    public var mqttClientKit: MqttClientKit {
        get { self[MqttClientKit.self] }
        set { self[MqttClientKit.self] = newValue }
    }
}

extension MqttClientKit: DependencyKey {
    public static var liveValue: Self {
        var connection: MQTTClient?

        func requireConnection(_ connection: MQTTClient?) throws -> MQTTClient {
            guard let connection else {
                throw MQTTError.noConnection
            }
            return connection
        }

        return Self(
            connect: { info in
                do {
                    connection = MQTTClient(
                        host: info.address,
                        port: info.port,
                        identifier: info.clientID,
                        eventLoopGroupProvider: .shared(.singletonMultiThreadedEventLoopGroup)
                    )

                    try await connection?.connect()
                    return AsyncStream { continuation in
                        Task {
                            continuation.yield(.connected)

                            connection?.addCloseListener(named: info.clientID) { _ in
                                continuation.yield(.disconnected(.closeUnexpect))
                                continuation.finish()
                            }

                            connection?.addShutdownListener(named: info.clientID) { result in
                                switch result {
                                case .success:
                                    continuation.yield(.idle)
                                case .failure(let error):
                                    continuation.yield(.disconnected(.underlying(error)))
                                }
                                continuation.finish()
                            }
                        }
                    }
                } catch ChannelError.connectTimeout(_) {
                    try? connection?.syncShutdownGracefully()
                    return AsyncStream { continuation in
                        continuation.yield(.disconnected(.timeout))
                        continuation.finish()
                    }
                } catch {
                    try? connection?.syncShutdownGracefully()
                    return AsyncStream { continuation in
                        continuation.yield(.disconnected(.underlying(error)))
                        continuation.finish()
                    }
                }

            }, disconnect: {
                try await requireConnection(connection).disconnect()
            }, publish: { info in
                try await requireConnection(connection).publish(to: info.topicName, payload: info.payload, qos: info.qos, retain: info.retain)
            }, subscribe: { info in
                do {
                    let ack = try await requireConnection(connection).subscribe(to: [info])
                    return ack
                } catch {
                    throw error
                }
            }, unsubscribe: { topic in
                do {
                    try await requireConnection(connection).unsubscribe(from: [topic])
                } catch {
                    throw error
                }
            },
            isActive: {
                try requireConnection(connection).isActive()
            },
            received: {
                AsyncThrowingStream<MQTTPublishInfo, Error> { continuation in
                    Task {
                        do {
                            let client = try requireConnection(connection)
                            let listener = client.createPublishListener()
                            for await result in listener {
                                switch result {
                                case .success(let info):
                                    continuation.yield(info)
                                case .failure(let error):
                                    continuation.finish(throwing: MqttClientKitError.underlying(error))
                                }
                            }
                        } catch {
                            continuation.finish(throwing: MqttClientKitError.noConnection)
                        }
                    }
                }
            }
        )
    }

    public static var testValue: Self {
        Self(
            connect: { _ in
                AsyncStream { continuation in
                    continuation.yield(.connected)
                    continuation.finish()
                }
            },
            disconnect: {},
            publish: { _ in
                throw UnimplementedFailure(description: "This is test client.")
            },
            subscribe: { _ in
                throw UnimplementedFailure(description: "This is test client.")
            },
            unsubscribe: { _ in
                throw UnimplementedFailure(description: "This is test client.")
            },
            isActive: {
                true
            },
            received: {
                AsyncThrowingStream { continuation in
                    Task {
                        for i in 1 ... 3 {
                            let jsonString = """
                            {"status": 1, "total_stripes": 10, "current_stripe": \(i)}
                            """
                            let info = MQTTPublishInfo(
                                qos: .atLeastOnce,
                                retain: false,
                                topicName: "painting",
                                payload: ByteBuffer(data: jsonString.data(using: .utf8)!),
                                properties: .init([])
                            )
                            continuation.yield(info)
                            try? await Task.sleep(nanoseconds: 100_000_000)
                        }
                        continuation.finish()
                    }
                }
            }
        )
    }
}
