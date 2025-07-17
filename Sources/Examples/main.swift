import ComposableArchitecture
import Foundation
import MqttClientKit

let store = Store(initialState: MqttFeature.State()) { MqttFeature() }

// Example of how to interact with the store
Task {
    await store.send(.connectButtonTapped).finish()
}

// Keep the program running to receive messages
RunLoop.main.run()
