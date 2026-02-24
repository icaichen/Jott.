# 集成 Gumroad 支付指南 (个人开发者首选)

Gumroad 是最适合个人开发者的支付平台，它不强制要求你拥有公司实体，且支持通过 PayPal 收款（非常适合中国开发者）。

## 1. 注册与配置

1.  访问 [Gumroad 官网](https://gumroad.com) 并注册账号。
2.  进入 **Settings > Payouts**，填写你的个人信息。
    *   **Account type**: 选择 **Individual** (个人)。
    *   **Identity Verification**: 上传身份证或护照。
    *   **Payout method**: 填写你的 **PayPal** 账号（如果你没有海外银行账户，PayPal 是最方便的）。

## 2. 创建产品

1.  点击 **Products** -> **New Product**。
2.  选择 **"Digital Product"** (数字产品)。
3.  输入名称 (如 "Jot Pro Lifetime") 和价格。
4.  在产品编辑页面的 **Content** 栏目：
    *   上传你的 DMG/ZIP 文件。
    *   或者勾选 "Redirect to a URL after purchase" 并填入你的下载页面（如果你希望用户回官网下载）。
5.  **关键步骤**: 在产品编辑页面的 **Checkout** 栏目，确保勾选 **"Generate a unique license key per sale"** (每笔销售生成唯一激活码)。
6.  发布产品 (Publish)。

## 3. 获取 Permalink

1.  发布后，你会获得一个购买链接，例如 `https://gumroad.com/l/my-cool-app`。
2.  链接的最后一部分 `my-cool-app` 就是你的 **Product Permalink**。
3.  打开 Xcode 项目中的 `Sources/Jot/Store/LicenseStore.swift`。
4.  将 `gumroadProductPermalink` 的值修改为你自己的 Permalink。

## 4. 构建与发布

1.  确保 `Distribution.swift` 中的 `currentDistributionChannel = .direct`。
2.  在 Xcode 中 Archive 并导出应用 (Direct Distribution)。
3.  打包并上传到你的网站。

## 常见问题

*   **Gumroad 费率是多少？** 
    *   Gumroad 收取 10% 的平台费 + 信用卡处理费（约 2.9% + $0.30）。虽然比 Stripe 贵，但它处理了所有税务和合规问题，对个人开发者来说非常省心。
*   **什么时候能收到钱？**
    *   Gumroad 每周五通过 PayPal 结算上周的余额（需满 $10）。
*   **需要自己处理退款吗？**
    *   你可以在 Gumroad 后台处理退款。如果退款发生，该激活码会自动失效（`LicenseStore.swift` 中的验证逻辑已经处理了这一点）。
