import ComposableArchitecture
import Foundation
import MqttClientKit

@Reducer
public struct MqttFeature {
    @ObservableState
    public struct State: Equatable {
        public var isConnected = false
        public var receivedMessages: [String] = []
    }

    @CasePathable
    public enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
        case view(ViewAction)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        
        @CasePathable
        public enum ViewAction: Equatable {
            case connectButtonTapped
            case disconnectButtonTapped
        }
        
        @CasePathable
        public enum Delegate: Equatable {
            // Add delegate actions if needed
        }
        
        case mqtt(MqttClientKit.State)
        case receivedMessage(String)
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce(core)
    }
    
    public func core(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .view(viewAction):
            switch viewAction {
            case .connectButtonTapped:
                return .run { send in
                    @Dependency(\.mqttClientKit) var mqttClient
                    let stream = await mqttClient.connect(.init(address: "localhost", port: 1883, clientID: "tca-example"))
                    for await mqttState in stream {
                        await send(.mqtt(mqttState))
                    }
                }

            case .disconnectButtonTapped:
                return .run { _ in
                    @Dependency(\.mqttClientKit) var mqttClient
                    try await mqttClient.disconnect()
                }
            }
            
        case .binding:
            return .none
            
        case .delegate:
            return .none

        case let .mqtt(mqttState):
            switch mqttState {
            case .connected:
                state.isConnected = true
            case .disconnected:
                state.isConnected = false
            case .idle, .connecting:
                break
            }
            return .none

        case let .receivedMessage(message):
            state.receivedMessages.append(message)
            return .none
        }
    }
}
