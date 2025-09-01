//
//  MqttExampleView.swift
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

private let logger = Logger(subsystem: "MqttClientKit.Examples", category: "MqttExampleView")

/// A comprehensive example showing how to use MqttClientKit with SwiftUI and TCA.
/// This view demonstrates:
/// - MQTT connection management
/// - Publishing messages to topics
/// - Subscribing to topics and receiving messages
/// - Connection settings configuration
/// - Error handling and status display
@ViewAction(for: MqttFeature.self)
struct MqttExampleView: View {
  @Bindable var store: StoreOf<MqttFeature>
  
  init(store: StoreOf<MqttFeature>) {
    self.store = store
  }
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        // Connection Status Section
        connectionStatusSection
        
        // Connection Controls
        connectionControlsSection
        
        Divider()
        
        // Publisher Section
        publisherSection
        
        Divider()
        
        // Subscriber Section
        subscriberSection
      }
      .padding()
      .navigationTitle("MQTT Example")
      .toolbar {
        ToolbarItem(placement: .automatic) {
          Button("Settings") {
            send(.connectionSettingsButtonTapped)
          }
        }
      }
      .sheet(isPresented: $store.showingConnectionSettings) {
        ConnectionSettingsView(store: store)
      }
    }
  }
  
  // MARK: - Connection Status Section
  private var connectionStatusSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Connection Status")
          .font(.headline)
        Spacer()
        connectionStatusIndicator
      }
      
      VStack(alignment: .leading, spacing: 4) {
        Text("Server: \(store.connectionInfo.address):\(store.connectionInfo.port)")
          .font(.caption)
          .foregroundColor(.secondary)
        Text("Client ID: \(store.connectionInfo.clientID)")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding()
    .background(.quaternary)
    .cornerRadius(8)
  }
  
  private var connectionStatusIndicator: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(connectionStatusColor)
        .frame(width: 8, height: 8)
      
      Text(connectionStatusText)
        .font(.caption)
        .fontWeight(.medium)
    }
  }
  
  private var connectionStatusColor: Color {
    switch store.connectionState {
    case .connected:
      return .green
    case .connecting:
      return .orange
    case .idle:
      return .gray
    case .disconnected:
      return .red
    }
  }
  
  private var connectionStatusText: String {
    switch store.connectionState {
    case .connected:
      return "Connected"
    case .connecting:
      return "Connecting"
    case .idle:
      return "Idle"
    case .disconnected(let error):
      return "Disconnected (\(error.errorDescription ?? "Unknown"))"
    }
  }
  
  // MARK: - Connection Controls Section
  private var connectionControlsSection: some View {
    HStack(spacing: 12) {
      Button("Connect") {
        send(.connectButtonTapped)
      }
      .buttonStyle(.borderedProminent)
      .disabled(!store.canConnect)
      
      Button("Disconnect") {
        send(.disconnectButtonTapped)
      }
      .buttonStyle(.bordered)
      .disabled(!store.canDisconnect)
      
      if store.isConnecting {
        ProgressView()
          .scaleEffect(0.8)
      }
    }
  }
  
  // MARK: - Publisher Section
  private var publisherSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Publish Message")
        .font(.headline)
      
      MqttPublisherView(
        store: store.scope(state: \.publisher, action: \.publisher)
      )
    }
  }
  
  // MARK: - Subscriber Section
  private var subscriberSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Subscriptions & Messages")
        .font(.headline)
      
      MqttSubscriberView(
        store: store.scope(state: \.subscriber, action: \.subscriber)
      )
    }
  }
}

// MARK: - Connection Settings View
private struct ConnectionSettingsView: View {
  @Bindable var store: StoreOf<MqttFeature>
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationStack {
      Form {
        Section("Server Settings") {
          TextField("Server Address", text: $store.connectionInfo.address)
            .textFieldStyle(.roundedBorder)
          
          HStack {
            Text("Port")
            Spacer()
            TextField("Port", value: $store.connectionInfo.port, format: .number)
              .textFieldStyle(.roundedBorder)
              .frame(width: 80)
          }
        }
        
        Section("Client Settings") {
          TextField("Client ID", text: $store.connectionInfo.clientID)
            .textFieldStyle(.roundedBorder)
          
          Button("Generate New Client ID") {
            store.connectionInfo.clientID = "mqtt-client-\(UUID().uuidString.prefix(8))"
          }
          .buttonStyle(.plain)
        }
        
        Section("Quick Presets") {
          Button("Local Development (localhost:1883)") {
            store.connectionInfo.address = "localhost"
            store.connectionInfo.port = 1883
          }
          .buttonStyle(.plain)
          
          Button("Eclipse Test Server (test.mosquitto.org:1883)") {
            store.connectionInfo.address = "test.mosquitto.org"
            store.connectionInfo.port = 1883
          }
          .buttonStyle(.plain)
        }
      }
      .navigationTitle("Connection Settings")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
          .fontWeight(.semibold)
        }
      }
    }
  }
}

// MARK: - Publisher View
@ViewAction(for: MqttPublisherFeature.self)
private struct MqttPublisherView: View {
  @Bindable var store: StoreOf<MqttPublisherFeature>
  @State private var topicInput = "test/topic"
  @State private var messageInput = "Hello MQTT!"
  @State private var qosSelection: MQTTQoS = .atMostOnce
  @State private var retainMessage = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Group {
        TextField("Topic", text: $topicInput)
          .textFieldStyle(.roundedBorder)
        
        TextField("Message", text: $messageInput, axis: .vertical)
          .textFieldStyle(.roundedBorder)
          .lineLimit(3...6)
        
        HStack {
          Text("QoS:")
          Picker("QoS", selection: $qosSelection) {
            Text("0 (At most once)").tag(MQTTQoS.atMostOnce)
            Text("1 (At least once)").tag(MQTTQoS.atLeastOnce)
            Text("2 (Exactly once)").tag(MQTTQoS.exactlyOnce)
          }
          .pickerStyle(.menu)
        }
        
        Toggle("Retain Message", isOn: $retainMessage)
      }
      
      Button("Publish") {
        // 首先設定發布資訊
        store.publishInfo = MQTTPublishInfo(
          qos: qosSelection,
          retain: retainMessage,
          topicName: topicInput,
          payload: ByteBuffer(string: messageInput),
          properties: .init([])
        )
        // 然後觸發發布
        send(.publishButtonTapped)
      }
      .buttonStyle(.borderedProminent)
      .disabled(topicInput.isEmpty || store.isPublishing)
      
      if store.isPublishing {
        HStack {
          ProgressView()
            .scaleEffect(0.8)
          Text("Publishing...")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding()
    .background(.quaternary)
    .cornerRadius(8)
  }
}

// MARK: - Subscriber View
@ViewAction(for: MqttSubscriberFeature.self)
private struct MqttSubscriberView: View {
  @Bindable var store: StoreOf<MqttSubscriberFeature>
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Subscriptions Section
      subscriptionsSection
      
      // Messages Section
      messagesSection
    }
  }
  
  private var subscriptionsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Active Subscriptions (\(store.subscriptions.count))")
          .font(.subheadline)
          .fontWeight(.medium)
        
        Spacer()
        
        subscribeToCommonTopics()
      }
      
      if store.subscriptions.isEmpty {
        Text("No active subscriptions")
          .font(.caption)
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        LazyVStack(alignment: .leading, spacing: 4) {
          ForEach(store.subscriptions) { subscription in
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(subscription.topicFilter)
                  .font(.caption)
                  .fontWeight(.medium)
                Text("QoS: \(subscription.qos.rawValue)")
                  .font(.caption2)
                  .foregroundColor(.secondary)
              }
              
              Spacer()
              
              Button("Remove") {
                send(.unsubscribe(subscription.id))
              }
              .buttonStyle(.plain)
              .font(.caption)
              .foregroundColor(.red)
            }
            .padding(.vertical, 4)
            
            if subscription.id != store.subscriptions.last?.id {
              Divider()
            }
          }
        }
      }
    }
    .padding()
    .background(.quaternary)
    .cornerRadius(8)
    // Removed sheet for subscription form - now using direct action
  }
  
  private var messagesSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Received Messages (\(store.messages.count))")
        .font(.subheadline)
        .fontWeight(.medium)
      
      if store.messages.isEmpty {
        Text("No messages received")
          .font(.caption)
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(Array(store.messages.reversed().prefix(10))) { message in
              MessageRow(message: message)
            }
          }
        }
        .frame(maxHeight: 200)
      }
    }
    .padding()
    .background(.quaternary)
    .cornerRadius(8)
  }
}

// MARK: - Quick Subscription Helpers (for demo purposes)
private extension MqttSubscriberView {
  func subscribeToCommonTopics() -> some View {
    Menu("Quick Subscribe") {
      Button("test/#") {
        send(.subscribe(MQTTSubscribeInfo(
          topicFilter: "test/#",
          qos: .atMostOnce
        )))
      }
      Button("sensors/+/temperature") {
        send(.subscribe(MQTTSubscribeInfo(
          topicFilter: "sensors/+/temperature",
          qos: .atLeastOnce
        )))
      }
      Button("home/+/status") {
        send(.subscribe(MQTTSubscribeInfo(
          topicFilter: "home/+/status",
          qos: .atMostOnce
        )))
      }
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
  }
}

// MARK: - Message Row
private struct MessageRow: View {
  let message: MQTTPublishInfo
  
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(message.topicName)
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(.primary)
        
        Spacer()
        
        Text("QoS: \(message.qos.rawValue)")
          .font(.caption2)
          .foregroundColor(.secondary)
        
        if message.retain {
          Text("RETAIN")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.orange)
        }
      }
      
      Text(String(buffer: message.payload) ?? "Binary data")
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(3)
    }
    .padding(8)
    .background(.background)
    .cornerRadius(6)
  }
}

// MARK: - Previews
#Preview("MQTT Example - Disconnected") {
  MqttExampleView(
    store: Store(initialState: MqttFeature.State()) {
      MqttFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
  )
}

#Preview("MQTT Example - Connected") {
  MqttExampleView(
    store: Store(
      initialState: MqttFeature.State(
        subscriber: MqttSubscriberFeature.State(
          subscriptions: IdentifiedArrayOf(uniqueElements: [
            MQTTSubscribeInfo(topicFilter: "test/#", qos: .atMostOnce),
            MQTTSubscribeInfo(topicFilter: "sensors/+/temp", qos: .atLeastOnce)
          ])
        ),
        connectionState: .connected
      )
    ) {
      MqttFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
  )
}