# MqttClientKit Examples

這個目錄包含了展示如何使用 MqttClientKit 的範例 SwiftUI views。

## 範例概述

### 1. SimpleMqttView
**檔案**: `Views/SimpleMqttView.swift`

最簡單的 MQTT 客戶端範例，適合快速開始使用：

- ✅ 基本連線管理（連線/斷線）
- ✅ 發送簡單訊息到固定主題
- ✅ 連線狀態顯示
- ✅ 最近發送的訊息記錄

```swift
import SwiftUI

// 最簡單的使用方式
struct ContentView: View {
    var body: some View {
        SimpleMqttView()
    }
}
```

### 2. MqttExampleView
**檔案**: `Views/MqttExampleView.swift`

完整功能的 MQTT 客戶端範例，展示所有主要功能：

- ✅ 完整的連線管理和設定
- ✅ 發布訊息到任意主題
- ✅ 訂閱多個主題
- ✅ 接收和顯示訊息
- ✅ QoS 級別設定
- ✅ Retain 訊息支援
- ✅ 錯誤處理和狀態管理

```swift
import SwiftUI
import ComposableArchitecture

struct ContentView: View {
    var body: some View {
        MqttExampleView(
            store: Store(initialState: MqttFeature.State()) {
                MqttFeature()
            }
        )
    }
}
```

## 快速開始

### 1. 使用 SimpleMqttView

```swift
import SwiftUI
import MqttClientKit

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            SimpleMqttView()
        }
    }
}
```

### 2. 使用 MqttExampleView

```swift
import SwiftUI
import ComposableArchitecture
import MqttClientKit

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            MqttExampleView(
                store: Store(initialState: MqttFeature.State()) {
                    MqttFeature()
                }
            )
        }
    }
}
```

### 3. 預設連線設定

範例使用以下預設設定：

- **SimpleMqttView**: 連線到 `test.mosquitto.org:1883`
- **MqttExampleView**: 預設為 `localhost:1883`，可在設定中修改

### 4. 自訂連線資訊

```swift
// 建立自訂連線資訊
let connectionInfo = MqttClientKitInfo(
    address: "your-mqtt-broker.com",
    port: 1883,
    clientID: "your-client-id"
)

// 使用自訂連線資訊初始化
let store = Store(
    initialState: MqttFeature.State(connectionInfo: connectionInfo)
) {
    MqttFeature()
}
```

## 功能特色

### MqttExampleView 支援的功能：

1. **連線管理**
   - 視覺化連線狀態指示器
   - 連線/斷線按鈕
   - 連線設定界面

2. **發布訊息**
   - 自訂主題名稱
   - 多行訊息輸入
   - QoS 級別選擇（0, 1, 2）
   - Retain 訊息選項

3. **訂閱管理**
   - 新增/移除訂閱
   - 支援萬用字元主題（`#`, `+`）
   - QoS 級別設定

4. **訊息接收**
   - 即時顯示接收的訊息
   - 顯示主題名稱和 QoS 級別
   - Retain 訊息標示

### SimpleMqttView 特色：

1. **極簡設計**
   - 最少的 UI 元素
   - 一鍵連線/斷線
   - 快速發送訊息

2. **適合場景**
   - 學習 MQTT 基本概念
   - 快速測試 MQTT 連線
   - 簡單的發送訊息需求

## 測試建議

### 本地測試
1. 安裝 Mosquitto MQTT Broker
2. 啟動本地 broker：`mosquitto -p 1883`
3. 修改範例中的連線位址為 `localhost`

### 公開測試 Broker
範例預設使用 Eclipse 的公開測試 broker：
- 位址: `test.mosquitto.org`
- 埠號: `1883`
- 無需驗證

### 主題建議
- 測試主題: `test/#`
- 感測器資料: `sensors/+/temperature`
- 裝置狀態: `devices/+/status`

## 架構說明

這些範例基於 [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture) 建構，提供：

- 可預測的狀態管理
- 容易測試的架構
- 清晰的資料流向
- 優秀的 SwiftUI 整合

## 進階用法

查看 `MqttFeature.swift` 中的擴展方法：

```swift
// 僅用於發布
let publisherOnlyState = MqttFeature.State.publisherOnly(
    connectionInfo: connectionInfo
)

// 僅用於訂閱
let subscriberOnlyState = MqttFeature.State.subscriberOnly(
    topics: ["sensors/#", "devices/+/status"],
    connectionInfo: connectionInfo
)

// 預設訂閱
let stateWithSubs = MqttFeature.State.withSubscriptions(
    ["test/#", "home/+/temperature"]
)
```