# Jott — App ID 注册指南（developer.apple.com）

按下面步骤在开发者网站创建 App ID 后，App Store Connect 里就能选到 Bundle ID。

---

## 1. 用一句话描述 Jott - Sticky Notes（方便你填表）

**英文（推荐填在 Description）：**
> Jott - Sticky Notes is a simple sticky-note app for macOS. Create and manage notes with rich blocks (text, checklists), save them to your storage list, and get local reminders for todo due dates.

**中文：**
> Jott 是 macOS 上的便签应用，支持富文本与待办清单，可将便签保存到收纳列表，并为待办设置本地提醒。

---

## 2. 打开并登录

1. 打开：**https://developer.apple.com**
2. 用和 Xcode、App Store Connect **同一个** Apple ID 登录。

---

## 3. 进入 Identifiers

1. 顶部或左侧找到 **“Account”** 或 **“Certificates, Identifiers & Profiles”**。
2. 点 **“Identifiers”**（或 “Certificates, Identifiers & Profiles” → Identifiers）。

---

## 4. 新建 App ID

1. 点左上角 **“+”**（或 “Register an identifier”）。
2. 选 **“App IDs”** → **Continue**。
3. 选 **“App”**（不要选 App Clip 等）→ **Continue**。
4. 填表：
   - **Description**：`Jott - Sticky Notes` 或上面那段英文描述的前半句。
   - **Bundle ID**：选 **“Explicit”**，框里填：**`com.chencai.Jot`**（和 Xcode 里完全一致）。
5. **Capabilities（能力）**：**一个都不用勾**。  
   Jott 只用本地存储、本地通知和沙盒，不需要在 App ID 上开 Push、iCloud、Sign in with Apple 等。
6. 点 **“Continue”** → **“Register”**。

---

## 5. 我们需要的“能力”和“服务”（总结）

| 项目 | 是否需要 | 说明 |
|------|----------|------|
| **Push Notifications** | ❌ 不需要 | 只用本地提醒（UserNotifications），不涉及推送。 |
| **iCloud** | ❌ 不需要 | 数据只存本机。 |
| **Sign in with Apple** | ❌ 不需要 | 无登录。 |
| **App Groups** | ❌ 不需要 | 无扩展、无共享容器。 |
| **其他 Capabilities** | ❌ 不需要 | 当前版本都不需要。 |
| **App Services** | 无 | 同上，全部不勾即可。 |

**结论：注册 App ID 时，Capabilities 和 App Services 全部不勾，直接 Register 即可。**

---

## 6. 之后在 App Store Connect

1. 打开 **App Store Connect** → **My Apps**。
2. 创建新 App 或编辑现有 App。
3. 在 **Bundle ID** 下拉里选 **com.chencai.Jot**（若刚创建，可刷新页面或重新进一次）。
4. 其他按正常上架流程填（价格、截图、描述等）。

---

## 7. 和 Xcode 的对应关系

- **Xcode**：Signing & Capabilities 里已勾选 **Automatically manage signing**，并选了 Team。  
- **developer.apple.com**：这里只是把 **com.chencai.Jot** 登记成正式 App ID，让 App Store Connect 能识别。  
- **Jot.entitlements**：只有 App Sandbox 和“用户选择的文件读写”，不需要在 App ID 上额外开能力。

按上面做完，Bundle ID 就会在 App Store Connect 里出现并可选择。
