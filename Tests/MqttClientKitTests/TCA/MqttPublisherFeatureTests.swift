//
//  MqttPublisherFeatureTests.swift
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
final class MqttPublisherFeatureTests: XCTestCase {
  
  // MARK: - Initial State Tests
  func testInitialState() async {
    let store = TestStore(initialState: MqttPublisherFeature.State()) {
      MqttPublisherFeature()
    }
    
    XCTAssertEqual(store.state.publishInfo.topicName, "")
    XCTAssertEqual(store.state.isPublishing, false)
    XCTAssertEqual(store.state.canPublish, false) // Empty topic
  }
  
  func testInitialStateWithData() async {
    let state = MqttPublisherFeature.State(
      topic: "test/topic",
      payload: "Hello World",
      qos: .atLeastOnce,
      retain: true
    )
    
    let store = TestStore(initialState: state) {
      MqttPublisherFeature()
    }
    
    XCTAssertEqual(store.state.publishInfo.topicName, "test/topic")
    XCTAssertEqual(store.state.payload, "Hello World")
    XCTAssertEqual(store.state.publishInfo.qos, .atLeastOnce)
    XCTAssertEqual(store.state.publishInfo.retain, true)
    XCTAssertEqual(store.state.canPublish, true)
  }
  
  // MARK: - Computed Properties Tests
  func testComputedProperties() async {
    var state = MqttPublisherFeature.State()
    
    // Test topic setter
    state.topic = "home/temperature"
    XCTAssertEqual(state.publishInfo.topicName, "home/temperature")
    
    // Test payload setter
    state.payload = "23.5"
    XCTAssertEqual(state.payload, "23.5")
    
    // Test qos setter
    state.qos = .atLeastOnce
    XCTAssertEqual(state.publishInfo.qos, .atLeastOnce)
    
    // Test retain setter
    state.retain = true
    XCTAssertEqual(state.publishInfo.retain, true)
    
    // Test canPublish
    XCTAssertEqual(state.canPublish, true)
    
    // Test canPublish with empty topic
    state.topic = ""
    XCTAssertEqual(state.canPublish, false)
  }
  
  // MARK: - Publish Flow Tests
  func testPublishSuccess() async {
    let state = MqttPublisherFeature.State(
      topic: "test/topic",
      payload: "Hello World"
    )
    
    let store = TestStore(initialState: state) {
      MqttPublisherFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
    
    await store.send(\.view.publishButtonTapped)
    await store.receive(\.publishStarted) {
      $0.isPublishing = true
    }
    await store.receive(\.publishCompleted) {
      $0.isPublishing = false
    }
    await store.receive(\.delegate.messagePublished, MQTTPublishInfo(
      qos: .atMostOnce,
      retain: false,
      topicName: "test/topic",
      payload: ByteBuffer(string: "Hello World"),
      properties: .init([])
    ))
  }
  
  func testPublishFailure() async {
    let state = MqttPublisherFeature.State(
      topic: "test/topic",
      payload: "Hello World"
    )
    
    let store = TestStore(initialState: state) {
      MqttPublisherFeature()
    } withDependencies: {
      $0.mqttClientKit = MqttClientKit(
        connect: { _ in AsyncStream { $0.yield(.connected); $0.finish() } },
        disconnect: {},
        publish: { _ in throw MqttClientKitError.noConnection },
        subscribe: { _ in throw MqttClientKitError.noConnection },
        unsubscribe: { _ in },
        isActive: { false },
        received: { AsyncThrowingStream { $0.finish() } }
      )
    }
    
    await store.send(\.view.publishButtonTapped)
    await store.receive(\.publishStarted) {
      $0.isPublishing = true
    }
    await store.receive(\.publishFailed, .noConnection) {
      $0.isPublishing = false
    }
    await store.receive(\.delegate.publishErrorOccurred, .noConnection)
  }
  
  func testPublishEmptyTopic() async {
    let state = MqttPublisherFeature.State(
      topic: "", // Empty topic
      payload: "Hello World"
    )
    
    let store = TestStore(initialState: state) {
      MqttPublisherFeature()
    }
    
    await store.send(\.view.publishButtonTapped)
    // Should not trigger any effects when topic is empty
  }
  
  // MARK: - Clear Form Tests
  func testClearForm() async {
    let state = MqttPublisherFeature.State(
      topic: "test/topic",
      payload: "Hello World",
      qos: .atLeastOnce,
      retain: true
    )
    
    let store = TestStore(initialState: state) {
      MqttPublisherFeature()
    }
    
    await store.send(\.view.clearFormButtonTapped) {
      $0.publishInfo = MQTTPublishInfo(
        qos: .atMostOnce,
        retain: false,
        topicName: "",
        payload: ByteBuffer(),
        properties: .init([])
      )
    }
  }
  
  // MARK: - Direct Publish Tests
  func testDirectPublishSuccess() async {
    let publishInfo = MQTTPublishInfo(
      qos: .atLeastOnce,
      retain: true,
      topicName: "direct/topic",
      payload: ByteBuffer(string: "Direct message"),
      properties: .init([])
    )
    
    let store = TestStore(initialState: MqttPublisherFeature.State()) {
      MqttPublisherFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
    
    await store.send(\.publish, publishInfo)
    await store.receive(\.publishStarted) {
      $0.isPublishing = true
    }
    await store.receive(\.publishCompleted) {
      $0.isPublishing = false
    }
    await store.receive(\.delegate.messagePublished, publishInfo)
  }
  
  func testPublishWithDetailsSuccess() async {
    let store = TestStore(initialState: MqttPublisherFeature.State()) {
      MqttPublisherFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
    
    await store.send(.publishWithDetails(topic: "details/topic", payload: "Details message", qos: .exactlyOnce, retain: true))
    await store.receive(\.publishStarted) {
      $0.isPublishing = true
    }
    await store.receive(\.publishCompleted) {
      $0.isPublishing = false
    }
    await store.receive(\.delegate.messagePublished, MQTTPublishInfo(
      qos: .exactlyOnce,
      retain: true,
      topicName: "details/topic",
      payload: ByteBuffer(string: "Details message"),
      properties: .init([])
    ))
  }
  
  func testDirectPublishEmptyTopic() async {
    let publishInfo = MQTTPublishInfo(
      qos: .atMostOnce,
      retain: false,
      topicName: "", // Empty topic
      payload: ByteBuffer(string: "Message"),
      properties: .init([])
    )
    
    let store = TestStore(initialState: MqttPublisherFeature.State()) {
      MqttPublisherFeature()
    }
    
    await store.send(\.publish, publishInfo)
    // Should not trigger any effects when topic is empty
  }

  // MARK: - Binding Tests
  func testBindingActions() async {
    let store = TestStore(initialState: MqttPublisherFeature.State()) {
      MqttPublisherFeature()
    }
    
    // Test binding actions are handled without side effects
    await store.send(\.binding, .set(\.topic, "new/topic")) {
      $0.topic = "new/topic"
    }
  }
}
