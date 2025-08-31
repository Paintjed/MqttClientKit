//
//  SimpleMqttView.swift
//  MqttClientKit Examples
//
//  Created by Claude on 2025/8/31.
//

import SwiftUI
import ComposableArchitecture
import MQTTNIO
import MqttClientKit
import OSLog
import NIOCore

private let logger = Logger(subsystem: "MqttClientKit.Examples", category: "SimpleMqttView")

/// A simple example showing basic MQTT usage with minimal setup.
/// This view demonstrates:
/// - Quick connection to MQTT broker
/// - Sending a simple message
/// - Basic connection status display
///
/// Perfect for getting started or when you only need basic MQTT functionality.
struct SimpleMqttView: View {
  @State private var store = Store(initialState: SimpleMqttFeature.State()) {
    SimpleMqttFeature()
  }
  
  init() {}
  
  var body: some View {
    VStack(spacing: 24) {
      // Title
      Text("Simple MQTT Client")
        .font(.largeTitle)
        .fontWeight(.bold)
      
      // Connection Status
      connectionStatus
      
      // Quick Actions
      actionButtons
      
      // Message Section
      messageSection
      
      Spacer()
    }
    .padding()
    .task {
      store.send(.task)
    }
  }
  
  private var connectionStatus: some View {
    VStack(spacing: 8) {
      HStack {
        Circle()
          .fill(store.isConnected ? .green : .red)
          .frame(width: 12, height: 12)
        
        Text(store.isConnected ? "Connected" : "Disconnected")
          .font(.headline)
      }
      
      Text("Server: \(store.serverAddress)")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding()
    .background(.quaternary)
    .cornerRadius(12)
  }
  
  private var actionButtons: some View {
    HStack(spacing: 16) {
      Button(store.isConnected ? "Disconnect" : "Connect") {
        if store.isConnected {
          store.send(.disconnectTapped)
        } else {
          store.send(.connectTapped)
        }
      }
      .buttonStyle(.borderedProminent)
      .disabled(store.isConnecting)
      
      if store.isConnecting {
        ProgressView()
          .scaleEffect(0.8)
      }
    }
  }
  
  private var messageSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Send Message")
        .font(.headline)
      
      VStack(spacing: 8) {
        TextField("Enter message", text: $store.messageText)
          .textFieldStyle(.roundedBorder)
        
        Button("Send to 'test/simple'") {
          store.send(.sendMessageTapped)
        }
        .buttonStyle(.bordered)
        .disabled(!store.isConnected || store.messageText.isEmpty)
      }
      
      if !store.sentMessages.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Recent Messages")
            .font(.subheadline)
            .fontWeight(.medium)
          
          ForEach(Array(store.sentMessages.suffix(3).reversed()), id: \.timestamp) { message in
            HStack {
              Text(message.text)
                .font(.caption)
              Spacer()
              Text(message.timestamp.formatted(.dateTime.hour().minute().second()))
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(8)
            .background(.background)
            .cornerRadius(6)
          }
        }
      }
    }
    .padding()
    .background(.quaternary)
    .cornerRadius(12)
  }
}

// MARK: - Simple MQTT Feature
@Reducer
private struct SimpleMqttFeature {
  @ObservableState
  struct State: Equatable {
    var isConnected = false
    var isConnecting = false
    var serverAddress = "test.mosquitto.org:1883"
    var messageText = "Hello from SimpleMqttView!"
    var sentMessages: [SentMessage] = []
    
    struct SentMessage: Equatable {
      let text: String
      let timestamp: Date
    }
  }
  
  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case task
    case connectTapped
    case disconnectTapped
    case sendMessageTapped
    case connectionStateChanged(MqttClientKit.State)
    case messageSent(String)
  }
  
  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce(core)
  }
  
  func core(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .binding:
      return .none
      
    case .task:
      // Initialize with test server connection info if needed
      return .none
      
    case .connectTapped:
      state.isConnecting = true
      return connectToMqtt()
      
    case .disconnectTapped:
      return disconnectFromMqtt()
      
    case .sendMessageTapped:
      let message = state.messageText
      return sendMessage(message)
      
    case .connectionStateChanged(let mqttState):
      state.isConnecting = false
      switch mqttState {
      case .connected:
        state.isConnected = true
      case .disconnected, .idle:
        state.isConnected = false
      case .connecting:
        state.isConnecting = true
      }
      return .none
      
    case .messageSent(let text):
      state.sentMessages.append(State.SentMessage(text: text, timestamp: Date()))
      return .none
    }
  }
  
  private func connectToMqtt() -> Effect<Action> {
    return .run { send in
      @Dependency(\.mqttClientKit) var mqttClient
      
      let connectionInfo = MqttClientKitInfo(
        address: "test.mosquitto.org",
        port: 1883,
        clientID: "simple-mqtt-\(UUID().uuidString.prefix(8))"
      )
      
      let stream = await mqttClient.connect(connectionInfo)
      for await state in stream {
        await send(.connectionStateChanged(state))
      }
    }
  }
  
  private func disconnectFromMqtt() -> Effect<Action> {
    return .run { _ in
      @Dependency(\.mqttClientKit) var mqttClient
      try await mqttClient.disconnect()
    }
  }
  
  private func sendMessage(_ text: String) -> Effect<Action> {
    return .run { send in
      @Dependency(\.mqttClientKit) var mqttClient
      
      let publishInfo = MQTTPublishInfo(
        qos: .atMostOnce,
        retain: false,
        topicName: "test/simple",
        payload: ByteBuffer(string: text),
        properties: .init([])
      )
      
      try await mqttClient.publish(publishInfo)
      await send(.messageSent(text))
    }
  }
}

// MARK: - Previews
#Preview("Simple MQTT - Disconnected") {
  SimpleMqttView()
}
//
//#Preview("Simple MQTT - Connected") {
//  let view = SimpleMqttView()
//  view.store.send(.connectionStateChanged(.connected))
//  view
//}
