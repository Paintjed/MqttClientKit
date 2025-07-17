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

    public enum Action {
        case connectButtonTapped
        case disconnectButtonTapped
        case mqtt(MqttClientKit.State)
        case receivedMessage(String)
    }

    @Dependency(\.mqttClientKit) var mqttClient

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .connectButtonTapped:
                return .run { send in
                    let stream = await mqttClient.connect(.init(address: "localhost", port: 1883, clientID: "tca-example"))
                    for await mqttState in stream {
                        await send(.mqtt(mqttState))
                    }
                }

            case .disconnectButtonTapped:
                return .run { _ in
                    try await mqttClient.disconnect()
                }

            case .mqtt(let mqttState):
                switch mqttState {
                case .connected:
                    state.isConnected = true
                case .disconnected:
                    state.isConnected = false
                default:
                    break
                }
                return .none

            case .receivedMessage(let message):
                state.receivedMessages.append(message)
                return .none
            }
        }
    }
}
