//
//  Distribution.swift
//  Jot
//
//  Created by Jot Dev on 2026-02-24.
//

import Foundation

/// 决定当前应用的发布渠道
enum DistributionChannel {
    case appStore
    case direct // 使用 Paddle 进行授权
}

/// 配置发布渠道
/// 将此设置为 .direct 以构建非 App Store 版本
let currentDistributionChannel: DistributionChannel = .direct

/// 是否为 App Store 版本
var isAppStoreBuild: Bool {
    return currentDistributionChannel == .appStore
}
