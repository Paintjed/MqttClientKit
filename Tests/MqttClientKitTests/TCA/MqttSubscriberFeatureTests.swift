//
//  MqttSubscriberFeatureTests.swift
//  MqttClientKitTests
//
//  Created by Jed Lu on 2025/8/31.
//

import XCTest
import ComposableArchitecture
@testable import MqttClientKit
import MQTTNIO
import NIOCore

@MainActor
final class MqttSubscriberFeatureTests: XCTestCase {
  
  // MARK: - Initial State Tests
  func testInitialState() async {
    let store = TestStore(initialState: MqttSubscriberFeature.State()) {
      MqttSubscriberFeature()
    }
    
    XCTAssertEqual(store.state.subscriptions, [])
    XCTAssertEqual(store.state.messages, [])
    XCTAssertEqual(store.state.maxMessages, 100)
    XCTAssertNil(store.state.lastError)
    XCTAssertEqual(store.state.hasError, false)
  }
  
  // MARK: - Computed Properties Tests
  func testComputedProperties() async {
    let subscriptions = [
      MQTTSubscribeInfo(topicFilter: "home/temperature", qos: .atLeastOnce),
      MQTTSubscribeInfo(topicFilter: "home/humidity", qos: .atMostOnce)
    ]
    
    var state = MqttSubscriberFeature.State(
      subscriptions: IdentifiedArrayOf(uniqueElements: subscriptions)
    )
    
    // Test activeSubscriptions - all should be active due to extension
    XCTAssertEqual(state.activeSubscriptions.count, 2)
    
    // Test hasError
    XCTAssertEqual(state.hasError, false)
    state.lastError = .noConnection
    XCTAssertEqual(state.hasError, true)
  }
  
  // MARK: - Subscription Management Tests
  func testAddSubscriptionSuccess() async {
    let store = TestStore(initialState: MqttSubscriberFeature.State()) {
      MqttSubscriberFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
    
    let subscribeInfo = MQTTSubscribeInfo(
      topicFilter: "home/temperature",
      qos: .atLeastOnce
    )
    
    await store.send(\.view.subscribe, subscribeInfo) {
      $0.subscriptions.append(subscribeInfo)
    }
    await store.receive(\.subscribeCompleted, "home/temperature")
    await store.receive(\.delegate.subscriptionAdded, subscribeInfo)
  }
  
  // MARK: - Message Handling Tests
  func testReceiveMessage() async {
    let store = TestStore(initialState: MqttSubscriberFeature.State()) {
      MqttSubscriberFeature()
    }
    
    let publishInfo = MQTTPublishInfo(
      qos: .atLeastOnce,
      retain: false,
      topicName: "home/temperature",
      payload: ByteBuffer(string: "23.5"),
      properties: .init([])
    )
    
    await store.send(\.messageReceived, publishInfo) {
      $0.messages.append(publishInfo)
    }
    await store.receive(\.delegate.messageReceived, publishInfo)
  }
  
  // MARK: - UI Actions Tests
  func testUnsubscribe() async {
    let subscribeInfo = MQTTSubscribeInfo(topicFilter: "home/temperature", qos: .atLeastOnce)
    let state = MqttSubscriberFeature.State(
      subscriptions: [subscribeInfo]
    )
    
    let store = TestStore(initialState: state) {
      MqttSubscriberFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
    
    await store.send(\.view.unsubscribe, subscribeInfo.id)
    await store.receive(\.unsubscribeCompleted, "home/temperature") {
      $0.subscriptions.removeAll()
    }
    await store.receive(\.delegate.subscriptionRemoved, "home/temperature")
  }
  
  func testClearMessages() async {
    let message = MQTTPublishInfo(
      qos: .atMostOnce,
      retain: false,
      topicName: "test",
      payload: ByteBuffer(),
      properties: .init([])
    )
    
    let state = MqttSubscriberFeature.State(
      messages: [message]
    )
    
    let store = TestStore(initialState: state) {
      MqttSubscriberFeature()
    }
    
    await store.send(\.view.clearMessages) {
      $0.messages.removeAll()
    }
  }
  
  // MARK: - Message Stream Tests
  func testMessageStreamStart() async {
    let store = TestStore(initialState: MqttSubscriberFeature.State()) {
      MqttSubscriberFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
      
    store.exhaustivity = .off(showSkippedAssertions: true)
    
    await store.send(\.view.task)
    await store.receive(\.messageStreamStarted)
  }
  
  // MARK: - Error Management Tests
  func testClearError() async {
    var state = MqttSubscriberFeature.State()
    state.lastError = .noConnection
    
    let store = TestStore(initialState: state) {
      MqttSubscriberFeature()
    }
    
    await store.send(\.view.clearError) {
      $0.lastError = nil
    }
  }
}
