//
//  MqttClientKit+Live.swift
//  MqttClientKit
//
//  Created by Jed Lu on 2025/7/15.
//

import ComposableArchitecture
import Foundation
import MQTTNIO
import NIOCore
import OSLog

extension MqttClientKit: DependencyKey {
  public static var liveValue: Self {
    let connectionManager = ConnectionManager()

    let logger = Logger(subsystem: "MqttClientKit", category: "MqttClientKit")
    return Self(
      connect: { info in
        do {
          logger.info(
            "Creating MQTTClient for host: \(info.address), port: \(info.port), clientID: \(info.clientID)"
          )
          let newConnection = MQTTClient(
            host: info.address,
            port: info.port,
            identifier: info.clientID,
            eventLoopGroupProvider: .shared(.singletonNIOTSEventLoopGroup)
          )

          try await newConnection.connect()
          await connectionManager.setConnection(newConnection)
          logger.info("MQTTClient connected successfully.")
          return AsyncStream { continuation in
            Task {
              continuation.yield(.connected)

              newConnection.addCloseListener(named: info.clientID) { _ in
                logger.warning("MQTTClient connection closed unexpectedly.")
                Task {
                  await connectionManager.clearConnection()
                }
                continuation.yield(.disconnected(.closeUnexpect))
                continuation.finish()
              }

              newConnection.addShutdownListener(named: info.clientID) { result in
                Task {
                  await connectionManager.clearConnection()
                }
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
          return AsyncStream { continuation in
            continuation.yield(.disconnected(.timeout))
            continuation.finish()
          }
        } catch {
          logger.error("MQTTClient connection error: \(String(describing: error))")
          return AsyncStream { continuation in
            continuation.yield(.disconnected(.underlying(error)))
            continuation.finish()
          }
        }
      },
      disconnect: {
        logger.info("Disconnecting MQTTClient...")
        let connection = try await connectionManager.getConnection()
        try await connection.disconnect()
        await connectionManager.clearConnection()
        logger.info("MQTTClient disconnected.")
      },
      publish: { info in
        logger.info(
          "Publishing to topic: \(info.topicName), payload size: \(info.payload.readableBytes)")
        let connection = try await connectionManager.getConnection()
        try await connection.publish(
          to: info.topicName, payload: info.payload, qos: info.qos, retain: info.retain)
        logger.info("Publish completed for topic: \(info.topicName)")
      },
      subscribe: { info in
        logger.info("Subscribing to topic: \(info.topicFilter)")
        do {
          let connection = try await connectionManager.getConnection()
          let ack = try await connection.subscribe(to: [info])
          logger.info("Subscribe completed for topic: \(info.topicFilter)")
          return ack
        } catch {
          logger.error(
            "Subscribe failed for topic: \(info.topicFilter), error: \(String(describing: error))")
          throw error
        }
      },
      unsubscribe: { topic in
        logger.info("Unsubscribing from topic: \(topic)")
        do {
          let connection = try await connectionManager.getConnection()
          try await connection.unsubscribe(from: [topic])
          logger.info("Unsubscribe completed for topic: \(topic)")
        } catch {
          logger.error(
            "Unsubscribe failed for topic: \(topic), error: \(String(describing: error))")
          throw error
        }
      },
      isActive: { 
        let active = try await connectionManager.isConnectionActive()
        logger.info("MQTTClient isActive: \(active)")
        return active
      },
      received: {
        logger.info("Starting to receive MQTT messages...")
        return AsyncThrowingStream<MQTTPublishInfo, Error> { continuation in
          Task {
            do {
              let client = try await connectionManager.getConnection()
              let listener = client.createPublishListener()
              for await result in listener {
                switch result {
                case .success(let info):
                  logger.info(
                    "Received message on topic: \(info.topicName), payload size: \(info.payload.readableBytes)"
                  )
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
}