//
//  LicenseStore.swift
//  Jot
//
//  Created by Jot Dev on 2026-02-24.
//

import Foundation
import Combine
import SwiftUI

/// Lemon Squeezy 授权验证
/// 文档: https://docs.lemonsqueezy.com/help/licensing/license-keys
@MainActor
class LicenseStore: ObservableObject {
    @Published var isProUnlocked: Bool = false
    @Published var licenseKey: String = ""
    @Published var isActivating: Bool = false
    @Published var activationError: String?

    private let licenseKeyStorageKey = "jot.license.key"
    
    // Lemon Squeezy 配置
    // 不需要填具体 ID，只需要购买链接即可。验证时只需要 License Key。
    // 将此链接替换为您的 Lemon Squeezy 产品购买链接
    let lemonSqueezyBuyURL = "https://your-store.lemonsqueezy.com/buy/your-product-id"

    init() {
        loadLicense()
    }

    /// 加载已保存的授权信息
    private func loadLicense() {
        if let savedKey = UserDefaults.standard.string(forKey: licenseKeyStorageKey),
           !savedKey.isEmpty {
            self.licenseKey = savedKey
            // 默认信任本地 Key
            self.isProUnlocked = true
            
            // 启动时静默验证 (验证 Key 是否有效/退款)
            Task {
                do {
                    let isValid = try await validateLicense(key: savedKey)
                    if !isValid {
                        await MainActor.run {
                            print("[License] Re-validation failed. Deactivating.")
                            self.deactivate()
                        }
                    } else {
                        print("[License] Re-validation success.")
                    }
                } catch {
                    print("[License] Re-validation error: \(error)")
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
            // 调用 Lemon Squeezy API 激活
            let isValid = try await activateLicenseAPI(key: cleanKey, instanceName: getDeviceName())
            
            if isValid {
                self.licenseKey = cleanKey
                self.isProUnlocked = true
                UserDefaults.standard.set(cleanKey, forKey: licenseKeyStorageKey)
            } else {
                self.activationError = "激活码无效、已过期或达到最大设备数"
                self.isProUnlocked = false
            }
        } catch {
            self.activationError = "验证失败: \(error.localizedDescription)"
            self.isProUnlocked = false
        }
        
        self.isActivating = false
    }
    
    /// 获取设备名称用于激活记录
    private func getDeviceName() -> String {
        return Host.current().localizedName ?? "Mac User"
    }
    
    /// 调用 Lemon Squeezy Activate API
    /// https://docs.lemonsqueezy.com/help/licensing/license-keys#activate-a-license-key
    private func activateLicenseAPI(key: String, instanceName: String) async throws -> Bool {
        guard let url = URL(string: "https://api.lemonsqueezy.com/v1/licenses/activate") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let bodyParams = [
            "license_key": key,
            "instance_name": instanceName
        ]
        
        let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let activated = json["activated"] as? Bool {
                return activated
            }
        }
        
        // 也可以解析 error 字段给用户更详细的提示
        return false
    }
    
    /// 调用 Lemon Squeezy Validate API (用于启动时检查)
    /// https://docs.lemonsqueezy.com/help/licensing/license-keys#validate-a-license-key
    private func validateLicense(key: String) async throws -> Bool {
        guard let url = URL(string: "https://api.lemonsqueezy.com/v1/licenses/validate") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Validate 只需要 key，不需要 instance_name (除非你想验证特定实例)
        let bodyParams = [
            "license_key": key
        ]
        
        let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        
        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let valid = json["valid"] as? Bool {
                return valid
            }
        }
        
        return false
    }
    
    /// 移除授权 (反激活)
    func deactivate() {
        // 可选：调用 Deactivate API 释放名额
        self.licenseKey = ""
        self.isProUnlocked = false
        UserDefaults.standard.removeObject(forKey: licenseKeyStorageKey)
    }
    
    /// 打开购买页面
    func openCheckout() {
        if let url = URL(string: lemonSqueezyBuyURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
