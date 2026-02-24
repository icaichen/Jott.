//
//  LicenseStore.swift
//  Jot
//
//  Created by Jot Dev on 2026-02-24.
//

import Foundation
import Combine
import SwiftUI

/// Gumroad 授权验证
@MainActor
class LicenseStore: ObservableObject {
    @Published var isProUnlocked: Bool = false
    @Published var licenseKey: String = ""
    @Published var isActivating: Bool = false
    @Published var activationError: String?

    private let licenseKeyStorageKey = "jot.license.key"
    
    // Gumroad 配置 (请替换为您的实际 Permalink)
    // Product Permalink 是您在 Gumroad 产品 URL 的最后一部分
    // 例如: https://username.gumroad.com/l/my-product-name -> Permalink 是 "my-product-name"
    let gumroadProductPermalink = "YOUR_PRODUCT_PERMALINK"

    init() {
        loadLicense()
    }

    /// 加载已保存的授权信息
    private func loadLicense() {
        if let savedKey = UserDefaults.standard.string(forKey: licenseKeyStorageKey),
           !savedKey.isEmpty {
            self.licenseKey = savedKey
            // 默认信任本地 Key，以免断网无法使用
            self.isProUnlocked = true
            
            // 异步静默复核 (Re-validation)
            // 检查退款状态或密钥是否失效
            Task {
                do {
                    // 使用 increment_uses_count: false 仅检查状态，不消耗激活次数
                    let isValid = try await verifyWithGumroad(licenseKey: savedKey, incrementUses: false)
                    if !isValid {
                        // 如果服务器明确返回无效（例如已退款），则撤销授权
                        await MainActor.run {
                            print("[License] Re-validation failed. Deactivating.")
                            self.deactivate()
                        }
                    } else {
                        print("[License] Re-validation success.")
                    }
                } catch {
                    // 网络错误等不撤销授权，保持本地信任
                    print("[License] Re-validation network error: \(error)")
                }
            }
        }
    }

    /// 激活授权
    func activate(key: String) async {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            self.activationError = "请输入激活码"
            return
        }
        
        self.isActivating = true
        self.activationError = nil
        
        do {
            // 首次激活时，incrementUses: true (可选，取决于你想不想限制设备数)
            // 这里我们设为 true，这样 Gumroad 会统计使用次数。
            // 你可以在 Gumroad 后台设置 "Limit uses" 来限制比如 2 台设备。
            let isValid = try await verifyWithGumroad(licenseKey: cleanKey, incrementUses: true)
            
            if isValid {
                self.licenseKey = cleanKey
                self.isProUnlocked = true
                UserDefaults.standard.set(cleanKey, forKey: licenseKeyStorageKey)
            } else {
                self.activationError = "激活码无效、已退款或达到最大激活次数"
                self.isProUnlocked = false
            }
        } catch {
            self.activationError = "验证失败: \(error.localizedDescription)"
            self.isProUnlocked = false
        }
        
        self.isActivating = false
    }
    
    /// 调用 Gumroad API 验证
    /// - Parameters:
    ///   - licenseKey: 激活码
    ///   - incrementUses: 是否增加使用次数计数 (true 用于首次激活，false 用于静默检查)
    private func verifyWithGumroad(licenseKey: String, incrementUses: Bool = false) async throws -> Bool {
        guard let url = URL(string: "https://api.gumroad.com/v2/licenses/verify") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Gumroad API 需要 product_permalink 和 license_key
        // 文档: https://app.gumroad.com/api#licenses-verify-license
        var bodyParams = [
            "product_permalink": gumroadProductPermalink,
            "license_key": licenseKey
        ]
        
        if incrementUses {
            bodyParams["increment_uses_count"] = "true"
        }
        
        let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        // Gumroad API 返回 200 表示成功，404 表示未找到等
        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool {
                
                // 检查退款状态
                if let purchase = json["purchase"] as? [String: Any] {
                    if let refunded = purchase["refunded"] as? Bool, refunded {
                        print("[License] License refunded.")
                        return false
                    }
                    if let chargebacked = purchase["chargebacked"] as? Bool, chargebacked {
                        print("[License] License chargebacked.")
                        return false
                    }
                }
                
                return success
            }
        } else if httpResponse.statusCode == 404 {
            // 404 通常意味着 Key 不存在或已被删除
            return false
        }
        
        return false
    }
    
    /// 移除授权 (反激活)
    func deactivate() {
        self.licenseKey = ""
        self.isProUnlocked = false
        UserDefaults.standard.removeObject(forKey: licenseKeyStorageKey)
    }
    
    /// 打开 Gumroad 购买页面
    func openCheckout() {
        if let url = URL(string: "https://gumroad.com/l/\(gumroadProductPermalink)") {
            NSWorkspace.shared.open(url)
        }
    }
}
