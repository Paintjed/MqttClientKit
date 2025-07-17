//
//  MqttClientKit.swift
//  Paintjet Foreman
//
//  Created by Jed Lu on 2025/7/15.
//

import ComposableArchitecture
import Foundation
import Logging
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

public enum MqttClientKitError: LocalizedError, Equatable {
    case timeout
    case closeUnexpect
    case noConnection
    case underlying(Swift.Error)

    public var errorDescription: String? {
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

    public var recoverySuggestion: String? {
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

    public static func == (lhs: MqttClientKitError, rhs: MqttClientKitError) -> Bool {
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
    public enum State: Equatable {
        case idle
        case connected
        case connecting
        case disconnected(MqttClientKitError)
    }

    public var connect: (MqttClientKitInfo) async -> AsyncStream<State>
    public var disconnect: () async throws -> ()
    public var publish: (MQTTPublishInfo) async throws -> ()
    public var subscribe: (MQTTSubscribeInfo) async throws -> MQTTSuback?
    public var unsubscribe: (Topic) async throws -> ()
    public var isActive: () throws -> Bool
    public var received: () -> AsyncThrowingStream<MQTTPublishInfo, Error>
}

public extension DependencyValues {
    var mqttClientKit: MqttClientKit {
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

        let logger = Logger(label: "MqttClientKit")
        return Self(
            connect: { info in
                do {
                    logger.info("Creating MQTTClient for host: \(info.address), port: \(info.port), clientID: \(info.clientID)")
                    connection = MQTTClient(
                        host: info.address,
                        port: info.port,
                        identifier: info.clientID,
                        eventLoopGroupProvider: .shared(.singletonNIOTSEventLoopGroup)
                    )

                    try await connection?.connect()
                    logger.info("MQTTClient connected successfully.")
                    return AsyncStream { continuation in
                        Task {
                            continuation.yield(.connected)

                            connection?.addCloseListener(named: info.clientID) { _ in
                                logger.warning("MQTTClient connection closed unexpectedly.")
                                continuation.yield(.disconnected(.closeUnexpect))
                                continuation.finish()
                            }

                            connection?.addShutdownListener(named: info.clientID) { result in
                                switch result {
                                case .success:
                                    logger.info("MQTTClient shutdown successfully.")
                                    continuation.yield(.idle)
                                case .failure(let error):
                                    logger.error("MQTTClient shutdown with error: \(String(describing: error))")
                                    continuation.yield(.disconnected(.underlying(error)))
                                }
                                continuation.finish()
                            }
                        }
                    }
                } catch ChannelError.connectTimeout(_) {
                    logger.error("MQTTClient connection timeout.")
                    try? connection?.syncShutdownGracefully()
                    return AsyncStream { continuation in
                        continuation.yield(.disconnected(.timeout))
                        continuation.finish()
                    }
                } catch {
                    logger.error("MQTTClient connection error: \(String(describing: error))")
                    try? connection?.syncShutdownGracefully()
                    return AsyncStream { continuation in
                        continuation.yield(.disconnected(.underlying(error)))
                        continuation.finish()
                    }
                }
            },
            disconnect: {
                logger.info("Disconnecting MQTTClient...")
                try await requireConnection(connection).disconnect()
                logger.info("MQTTClient disconnected.")
            },
            publish: { info in
                logger.info("Publishing to topic: \(info.topicName), payload size: \(info.payload.readableBytes)")
                try await requireConnection(connection).publish(to: info.topicName, payload: info.payload, qos: info.qos, retain: info.retain)
                logger.info("Publish completed for topic: \(info.topicName)")
            },
            subscribe: { info in
                logger.info("Subscribing to topic: \(info.topicFilter)")
                do {
                    let ack = try await requireConnection(connection).subscribe(to: [info])
                    logger.info("Subscribe completed for topic: \(info.topicFilter)")
                    return ack
                } catch {
                    logger.error("Subscribe failed for topic: \(info.topicFilter), error: \(String(describing: error))")
                    throw error
                }
            },
            unsubscribe: { topic in
                logger.info("Unsubscribing from topic: \(topic)")
                do {
                    try await requireConnection(connection).unsubscribe(from: [topic])
                    logger.info("Unsubscribe completed for topic: \(topic)")
                } catch {
                    logger.error("Unsubscribe failed for topic: \(topic), error: \(String(describing: error))")
                    throw error
                }
            },
            isActive: {
                let active = try requireConnection(connection).isActive()
                logger.info("MQTTClient isActive: \(active)")
                return active
            },
            received: {
                logger.info("Starting to receive MQTT messages...")
                return AsyncThrowingStream<MQTTPublishInfo, Error> { continuation in
                    Task {
                        do {
                            let client = try requireConnection(connection)
                            let listener = client.createPublishListener()
                            for await result in listener {
                                switch result {
                                case .success(let info):
                                    logger.info("Received message on topic: \(info.topicName), payload size: \(info.payload.readableBytes)")
                                    continuation.yield(info)
                                case .failure(let error):
                                    logger.error("Error receiving message: \(String(describing: error))")
                                    continuation.finish(throwing: MqttClientKitError.underlying(error))
                                }
                            }
                        } catch {
                            logger.error("Error in received stream: \(String(describing: error))")
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
