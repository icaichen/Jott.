//
//  LicenseView.swift
//  Jot
//
//  Created by Jot Dev on 2026-02-24.
//

import SwiftUI

struct LicenseView: View {
    @ObservedObject var licenseStore: LicenseStore
    @State private var inputKey: String = ""
    @State private var inputEmail: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Image("Jot logo") // 确保 Logo 名称正确
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 4)

            Text("激活 Jott Pro")
                .font(.title)
                .fontWeight(.bold)

            if licenseStore.isProUnlocked {
                // 已激活状态
                VStack(spacing: 12) {
                    Text("您的副本已激活")
                        .foregroundColor(.green)
                        .font(.headline)
                    
                    if !licenseStore.licenseKey.isEmpty {
                        // 显示部分 Key 以供确认
                        let key = licenseStore.licenseKey
                        let maskedKey = key.count > 4 ? "..." + key.suffix(4) : key
                        Text("License: \(maskedKey)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("取消激活") {
                        licenseStore.deactivate()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .padding(.top, 8)
                }
            } else {
                // 未激活状态
                VStack(spacing: 16) {
                    Text("请输入您的 License Key 以解锁完整功能。")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("License Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("XXXX-XXXX-XXXX-XXXX", text: $inputKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal, 32)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Button(action: activateLicense) {
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("立即激活")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(inputKey.isEmpty || isProcessing)
                    .padding(.horizontal, 32)
                    
                    HStack {
                        Text("还没有激活码？")
                        Button("立即购买") {
                            licenseStore.openCheckout()
                        }
                        .buttonStyle(.link)
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(32)
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
    }

    private func activateLicense() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            // Gumroad API 不需要邮箱，只需要 Key
            await licenseStore.activate(key: inputKey)
            isProcessing = false
            if !licenseStore.isProUnlocked {
                errorMessage = licenseStore.activationError ?? "激活失败"
            }
        }
    }
}
