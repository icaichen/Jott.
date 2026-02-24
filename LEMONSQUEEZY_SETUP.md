# 集成 Lemon Squeezy 支付指南 (推荐)

Lemon Squeezy 是目前对中国个人开发者最友好的 MoR 平台。

**优势：**
1.  **门槛极低**：无需公司，个人即可注册。
2.  **收款灵活**：支持 **PayPal** 和 **Wise** 收款。
3.  **支付方式全**：买家可以使用 **支付宝 (Alipay)**、**微信支付 (WeChat Pay)**、PayPal 和信用卡付款。这对中国用户非常友好。
4.  **税务合规**：作为 MoR 自动处理全球税务。

## 1. 注册与激活

1.  访问 [Lemon Squeezy 官网](https://www.lemonsqueezy.com) 并注册。
2.  进入 **Settings > Store**，完成商店设置。
3.  进入 **Settings > Payouts**，连接你的 PayPal 账号。

## 2. 创建产品

1.  点击 **Products** -> **New product**。
2.  **Name**: 输入应用名称 (如 "Jot Pro Lifetime")。
3.  **Pricing model**: 选择 **Standard pricing** (一次性付费)。
4.  **Price**: 设置价格 (如 $9.99)。
5.  **Files**: 上传你的 DMG/ZIP 文件。
6.  **License keys**: **关键步骤！**
    *   勾选 **"Generate license keys"**。
    *   **Activation limit**: 设置为 `2` 或 `3` (允许激活的设备数)。
    *   **Disable**: 建议勾选 "Restrict to product" (默认)。
7.  点击 **Publish product**。

## 3. 获取购买链接

1.  发布后，点击产品旁边的 **"Share"** 按钮。
2.  复制 **Checkout link** (购买链接)。
3.  打开 Xcode 项目中的 `Sources/Jot/Store/LicenseStore.swift`。
4.  修改 `lemonSqueezyBuyURL` 变量：
    ```swift
    let lemonSqueezyBuyURL = "https://your-store.lemonsqueezy.com/buy/..."
    ```

## 4. 构建与发布

1.  确保 `Distribution.swift` 中的 `currentDistributionChannel = .direct`。
2.  在 Xcode 中 Archive 并导出应用 (Direct Distribution)。
3.  打包并上传到你的网站。

## 常见问题

*   **什么时候能收到钱？**
    *   每月两次结算（1号和15号），通过 PayPal 打款。
*   **支持支付宝吗？**
    *   是的，Lemon Squeezy 的收银台（Checkout）自动支持支付宝和微信支付，无需额外配置。
