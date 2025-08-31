//
//  MQTTExtensions.swift
//  MqttClientKit
//
//  Created by Jed Lu on 2025/8/31.
//

import Foundation
import MQTTNIO
import NIOCore

// MARK: - MQTTPublishInfo Equatable Conformance
extension MQTTPublishInfo: @retroactive Equatable {
  public static func == (lhs: MQTTPublishInfo, rhs: MQTTPublishInfo) -> Bool {
    lhs.qos == rhs.qos &&
    lhs.retain == rhs.retain &&
    lhs.topicName == rhs.topicName &&
    lhs.payload == rhs.payload
  }
}

// MARK: - MQTTPublishInfo Identifiable Conformance
extension MQTTPublishInfo: @retroactive Identifiable {
  public var id: String {
    "\(topicName)-\(Date().timeIntervalSince1970)"
  }
}

// MARK: - MQTTSubscribeInfo Equatable Conformance
extension MQTTSubscribeInfo: @retroactive Equatable {
  public static func == (lhs: MQTTSubscribeInfo, rhs: MQTTSubscribeInfo) -> Bool {
    lhs.topicFilter == rhs.topicFilter &&
    lhs.qos == rhs.qos
  }
}

// MARK: - MQTTSubscribeInfo Extensions
extension MQTTSubscribeInfo: @retroactive Identifiable {
  public var id: String {
    "\(topicFilter)-\(qos.rawValue)"
  }
}

// MARK: - Helper properties for UI
extension MQTTSubscribeInfo {
  public var isActive: Bool {
    // Since we're using direct MQTTNIO types, we assume all subscriptions are active
    // This can be managed at a higher level if needed
    return true
  }
}
