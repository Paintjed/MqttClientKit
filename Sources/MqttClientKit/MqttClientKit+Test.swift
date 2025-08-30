//
//  MqttClientKit+Test.swift
//  MqttClientKit
//
//  Created by Jed Lu on 2025/7/15.
//

import ComposableArchitecture
import Foundation
import MQTTNIO
import NIOCore

extension MqttClientKit {
  public static var testValue: Self {
    final class State {
      var subscriptions = Set<String>()
      var publishedMessages = [MQTTPublishInfo]()
    }
    let state = LockIsolated(State())

    return Self(
      connect: { _ in
        AsyncStream { continuation in
          continuation.yield(.connected)
          continuation.finish()
        }
      },
      disconnect: {},
      publish: { info in
        state.withValue {
          if $0.subscriptions.contains(info.topicName) {
            $0.publishedMessages.append(info)
          }
        }
      },
      subscribe: { info in
        state.withValue { _ = $0.subscriptions.insert(info.topicFilter) }
        return nil
      },
      unsubscribe: { topic in
        state.withValue { _ = $0.subscriptions.remove(topic) }
      },
      isActive: {
        true
      },
      received: {
        AsyncThrowingStream { continuation in
          Task {
            for i in 1...3 {
              let jsonString = """
                {"status": 1, "total_stripes": 10, "current_stripe": \(i)}
                """
              let info = MQTTPublishInfo(
                qos: .atLeastOnce,
                retain: false,
                topicName: "painting",
                payload: ByteBuffer(data: jsonString.data(using: .utf8)!),
                properties: .init([])
              )
              continuation.yield(info)
              try? await Task.sleep(nanoseconds: 10_000_000)
            }

            let messages = state.withValue {
              let msgs = $0.publishedMessages
              $0.publishedMessages.removeAll()
              return msgs
            }

            for message in messages {
              continuation.yield(message)
            }

            continuation.finish()
          }
        }
      }
    )
  }
}