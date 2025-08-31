//
//  MqttClientKit.swift
//  Paintjet Foreman
//
//  Created by Jed Lu on 2025/7/15.
//

import Foundation
import MQTTNIO

public struct MqttClientKit: Sendable {
  public var connect: @Sendable (MqttClientKitInfo) async -> AsyncStream<State>
  public var disconnect: @Sendable () async throws -> Void
  public var publish: @Sendable (MQTTPublishInfo) async throws -> Void
  public var subscribe: @Sendable (MQTTSubscribeInfo) async throws -> MQTTSuback?
  public var unsubscribe: @Sendable (Topic) async throws -> Void
  public var isActive: @Sendable () async throws -> Bool
  public var received: @Sendable () -> AsyncThrowingStream<MQTTPublishInfo, Error>
  
  public init(
    connect: @escaping @Sendable (MqttClientKitInfo) async -> AsyncStream<State>,
    disconnect: @escaping @Sendable () async throws -> Void,
    publish: @escaping @Sendable (MQTTPublishInfo) async throws -> Void,
    subscribe: @escaping @Sendable (MQTTSubscribeInfo) async throws -> MQTTSuback?,
    unsubscribe: @escaping @Sendable (Topic) async throws -> Void,
    isActive: @escaping @Sendable () async throws -> Bool,
    received: @escaping @Sendable () -> AsyncThrowingStream<MQTTPublishInfo, Error>
  ) {
    self.connect = connect
    self.disconnect = disconnect
    self.publish = publish
    self.subscribe = subscribe
    self.unsubscribe = unsubscribe
    self.isActive = isActive
    self.received = received
  }
}