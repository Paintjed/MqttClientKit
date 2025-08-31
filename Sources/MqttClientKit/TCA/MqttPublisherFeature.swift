//
//  MqttPublisherFeature.swift
//  MqttClientKit
//
//  Created by Jed Lu on 2025/8/30.
//

import ComposableArchitecture
import Foundation
import MQTTNIO
import NIOCore
import OSLog

@Reducer
package struct MqttPublisherFeature {
    private let logger = Logger(subsystem: "MqttClientKit", category: "MqttPublisherFeature")
  
    // MARK: - State

    @ObservableState
    package struct State: Sendable, Equatable {
        package var publishInfo: MQTTPublishInfo
        package var isPublishing: Bool
    
        package init(
            publishInfo: MQTTPublishInfo = MQTTPublishInfo(
                qos: .atMostOnce,
                retain: false,
                topicName: "",
                payload: ByteBuffer(),
                properties: .init([])
            ),
            isPublishing: Bool = false
        ) {
            self.publishInfo = publishInfo
            self.isPublishing = isPublishing
        }
    
        // Convenience initializer for string-based input
        package init(
            topic: String = "",
            payload: String = "",
            qos: MQTTQoS = .atMostOnce,
            retain: Bool = false,
            isPublishing: Bool = false
        ) {
            self.publishInfo = MQTTPublishInfo(
                qos: qos,
                retain: retain,
                topicName: topic,
                payload: ByteBuffer(string: payload),
                properties: .init([])
            )
            self.isPublishing = isPublishing
        }
    
        // Computed properties for UI convenience
        package var topic: String {
            get { publishInfo.topicName }
            set {
                publishInfo = MQTTPublishInfo(
                    qos: publishInfo.qos,
                    retain: publishInfo.retain,
                    topicName: newValue,
                    payload: publishInfo.payload,
                    properties: publishInfo.properties
                )
            }
        }
    
        package var payload: String {
            get { String(buffer: publishInfo.payload) }
            set {
                publishInfo = MQTTPublishInfo(
                    qos: publishInfo.qos,
                    retain: publishInfo.retain,
                    topicName: publishInfo.topicName,
                    payload: ByteBuffer(string: newValue),
                    properties: publishInfo.properties
                )
            }
        }
    
        package var qos: MQTTQoS {
            get { publishInfo.qos }
            set {
                publishInfo = MQTTPublishInfo(
                    qos: newValue,
                    retain: publishInfo.retain,
                    topicName: publishInfo.topicName,
                    payload: publishInfo.payload,
                    properties: publishInfo.properties
                )
            }
        }
    
        package var retain: Bool {
            get { publishInfo.retain }
            set {
                publishInfo = MQTTPublishInfo(
                    qos: publishInfo.qos,
                    retain: newValue,
                    topicName: publishInfo.topicName,
                    payload: publishInfo.payload,
                    properties: publishInfo.properties
                )
            }
        }
    
        package var canPublish: Bool {
            !publishInfo.topicName.isEmpty && !isPublishing
        }
    }
    
    // MARK: - Body

    package var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce(core)
    }
}

package extension MqttPublisherFeature {
    // MARK: - Actions

    @CasePathable
    enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
        case view(ViewAction)
        case binding(BindingAction<State>)
        case delegate(Delegate)
    
        // Internal actions
        case publishStarted
        case publishCompleted
        case publishFailed(MqttClientKitError)
    
        @CasePathable
        package enum ViewAction: Equatable {
            case publishButtonTapped
            case clearFormButtonTapped
        }
    
        @CasePathable
        package enum Delegate: Equatable {
            case messagePublished(MQTTPublishInfo)
            case publishErrorOccurred(MqttClientKitError)
        }
    }

    // MARK: - Core Reducer

    func core(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .view(viewAction):
            return handleViewAction(&state, viewAction)
      
        case .binding:
            return .none
      
        case let .delegate(delegateAction):
            return handleDelegateAction(&state, delegateAction)
      
        case .publishStarted:
            state.isPublishing = true
            return .none
      
        case .publishCompleted:
            state.isPublishing = false
            let topicName = state.publishInfo.topicName
            logger.info("Message published successfully to topic: \(topicName)")
            return .none
      
        case let .publishFailed(error):
            state.isPublishing = false
            logger.error("Failed to publish message: \(error.localizedDescription)")
            return .send(.delegate(.publishErrorOccurred(error)))
        }
    }
}

// MARK: - Private Helper Methods

extension MqttPublisherFeature {
    private func handleViewAction(_ state: inout State, _ action: Action.ViewAction) -> Effect<Action> {
        switch action {
        case .publishButtonTapped:
            return publishMessage(&state)
      
        case .clearFormButtonTapped:
            state.publishInfo = MQTTPublishInfo(
                qos: .atMostOnce,
                retain: false,
                topicName: "",
                payload: ByteBuffer(),
                properties: .init([])
            )
            return .none
        }
    }
  
    private func handleDelegateAction(_ state: inout State, _ action: Action.Delegate) -> Effect<Action> {
        switch action {
        case .messagePublished, .publishErrorOccurred:
            // These are outbound delegate actions, no internal handling needed
            return .none
        }
    }
  
    private func publishMessage(_ state: inout State) -> Effect<Action> {
        guard state.canPublish else { return .none }
    
        let publishInfo = state.publishInfo
    
        return .run { send in
            await send(.publishStarted)
            @Dependency(\.mqttClientKit) var mqttClient
      
            do {
                // Check if client is active before publishing
                guard try await mqttClient.isActive() else {
                    throw MqttClientKitError.noConnection
                }
        
                try await mqttClient.publish(publishInfo)
                await send(.publishCompleted)
                await send(.delegate(.messagePublished(publishInfo)))
            } catch {
                let mqttError = error as? MqttClientKitError ?? .underlying(error)
                await send(.publishFailed(mqttError))
            }
        }
    }
}