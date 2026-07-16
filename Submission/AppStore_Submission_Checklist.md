# RepDay — App Store 提审清单(美区优先)

> 目标:把 RepDay 推到"可在美区提审"的状态。中国区备案可并行推进,不阻塞此清单。

## 0. 账号与主体
- [x] Apple Developer Program 已注册并生效($99/年)。
- [x] App Store Connect 中已创建 App 记录(Bundle ID:`com.zhoulinhua0-star.FitnessApp2026New`)。
- [x] Primary Language 设为 English (U.S.);之后可加 Simplified Chinese 本地化。

## 1. 代码 / 工程(本清单已帮你处理的部分)
- [x] **导出合规声明**:已在工程加入 `ITSAppUsesNonExemptEncryption = NO`
      → 提审时不会再反复弹"是否使用加密"。(应用仅用系统 HTTPS/标准加密,属豁免。)
- [x] **隐私清单 `PrivacyInfo.xcprivacy`**:已加入(声明无追踪、无数据收集、UserDefaults 属自用 CA92.1)。
      ⚠️ 请在 Xcode 里确认该文件的 **Target Membership 勾选了 FitnessApp** 主 App(同步文件夹通常会自动包含,archive 后可在包内验证)。
- [x] 权限用途说明已存在；日历授权说明已改成英文，适合美区首发。
- [x] 主 App 与 Widget 的 `MARKETING_VERSION` = 1.0.0,`CURRENT_PROJECT_VERSION`(build)= 2;每次上传 build 号要 +1。
- [x] Build 1 已完成 Archive、上传并通过 TestFlight 真机安装。
- [ ] 因英文权限说明更新，请重新 Archive 并上传 **Build 2**，最终提审选择 Build 2。

## 2. App Privacy(隐私"营养标签",在 App Store Connect 里填)
当前 App 全部数据都在设备本地、无账号、无第三方 SDK,所以:

- **Data Collection:** 选 **"No, we do not collect data from this app."**
  - 理由:训练数据仅存本地;日历是写入用户自己的日历,不算"收集";通知为本地通知。
- 因此无需逐项勾选数据类型。
- **Tracking:** 无(隐私清单里 `NSPrivacyTracking = false`)。

> 注:等以后上线 CloudKit 匿名计数器,仍可保持 "Data Not Collected"(匿名汇总、不含个人信息);若届时改动,再同步更新此项。

## 3. 隐私政策
- [x] RepDay Support/Privacy 网站已发布到公开 HTTPS 地址。
- [ ] 在 App Store Connect 的 App Privacy → Privacy Policy URL 填入：
      `https://repday-support.zhoulinhua0.chatgpt.site/privacy`
- [x] App 内“我的 → 关于”已加入可直接访问的英文隐私政策。

## 4. App Store 商品页(Product Page)
- [ ] App 名称、副标题(Subtitle)、关键词(Keywords)。
- [ ] 描述(Description)——英文。
- [ ] **截图**:上传 1–10 张 6.9" iPhone 截图即可;工程 `TARGETED_DEVICE_FAMILY = 1`,不需要 iPad 截图。
- [ ] App 图标 1024×1024(无 alpha 通道)。
- [ ] 分类:Primary = Health & Fitness。
- [ ] 年龄分级(Age Rating)问卷:健身内容一般 4+。
- [x] Support URL 已准备：`https://repday-support.zhoulinhua0.chatgpt.site/support`。

## 5. 审核信息
- [ ] Sign-In 要求:无账号 → 勾选不需要登录,无需提供测试账号。
- [ ] 备注(App Review Notes):说明这是纯本地健身工具、无账号、日历为可选授权。

## 6. 提交
- [ ] 上传 build(Xcode Organizer 或 Transporter)。
- [ ] 选中该 build → 填完以上 → Submit for Review。

---

## 待办(不阻塞美区,但建议尽快)
1. **中国区:ICP / App 备案** —— 找备案服务商确认当前口径,并行推进。

## 已知事实(备查)
- Bundle ID:`com.zhoulinhua0-star.FitnessApp2026New`
- Display Name:RepDay
- Team:VN3RC8953L
- 权限:日历(`NSCalendarsFullAccessUsageDescription`)、通知(`NSUserNotificationsUsageDescription`)
- 数据存储:SwiftData(设备本地),Widget 数据共享经 `WidgetDataStore`
