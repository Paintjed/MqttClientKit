//
//  main.swift
//  MqttClientKit Examples
//
//  Created by Claude on 2025/8/31.
//

import SwiftUI
import ComposableArchitecture
import MqttClientKit

struct ExamplesApp: App {
  var body: some Scene {
    WindowGroup {
      ExampleSelectionView()
    }
  }
}

struct ExampleSelectionView: View {
  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        Text("MQTT Client Examples")
          .font(.largeTitle)
          .fontWeight(.bold)
        
        VStack(spacing: 16) {
          NavigationLink {
            SimpleMqttView()
          } label: {
            ExampleCardView(
              title: "Simple MQTT",
              description: "Basic MQTT client with minimal setup",
              icon: "bolt.circle.fill"
            )
          }
          .buttonStyle(.plain)
          
          NavigationLink {
            MqttExampleView(
              store: Store(initialState: MqttFeature.State()) {
                MqttFeature()
              }
            )
          } label: {
            ExampleCardView(
              title: "Advanced MQTT with TCA",
              description: "Full-featured MQTT client with TCA architecture",
              icon: "network"
            )
          }
          .buttonStyle(.plain)
        }
        
        Spacer()
      }
      .padding()
      .navigationTitle("Examples")
    }
  }
}

struct ExampleCardView: View {
  let title: String
  let description: String
  let icon: String
  
  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: icon)
        .font(.largeTitle)
        .foregroundColor(.accentColor)
        .frame(width: 44, height: 44)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
          .foregroundColor(.primary)
        
        Text(description)
          .font(.caption)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.leading)
      }
      
      Spacer()
      
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding()
    .background(.quaternary)
    .cornerRadius(12)
  }
}

#Preview {
  ExampleSelectionView()
}
