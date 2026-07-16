# RepDay — App Store Connect 逐项填写指南

> 当前目标：免费 App、只在美国区首发、手动发布、最终使用 Version 1.0.0 / Build 2。

## 先确认你所在的位置

1. 在 Mac 浏览器打开 `https://appstoreconnect.apple.com/`。
2. 点击 **Apps**（或 **My Apps**）。
3. 点击 **RepDay**。
4. 后续绝大多数内容都在 RepDay 左侧导航栏中完成。

## A. 先上传 Build 2

项目已把日历权限说明改成英文，并把主 App 与 Widget 的 Build Number 从 1 提升为 2。因此 Build 1 可以保留做测试，但最终提交请选择 Build 2。

1. 打开 Xcode 工程。
2. 在顶部 Scheme 选择 **FitnessApp**。
3. Destination 选择 **Any iOS Device (arm64)** 或 **Generic iOS Device**，不要选模拟器。
4. 菜单点击 **Product → Archive**。
5. Archive 成功后，在 Organizer 选择最新的 `1.0.0 (2)`。
6. 点击 **Distribute App → App Store Connect → Upload**。
7. 保持 Xcode 默认的自动签名与上传选项，逐步点击 **Next**，最后点击 **Upload**。
8. 回到 App Store Connect → RepDay → **TestFlight**，等待 `1.0.0 (2)` 从 Processing 变为 Ready to Test / Ready to Submit。
9. 把 Build 2 加入你现有的内部测试组，并在 iPhone TestFlight 更新一次，重点触发日历权限，确认弹窗为英文。

## B. App Information（应用级信息）

路径：**RepDay → 左侧 General → App Information**。

### Localizable Information / English (U.S.)

- Name：`RepDay`
- Subtitle：`Workout Planner & Tracker`
- Privacy Policy URL：如果这个页面显示该字段，填：  
  `https://repday-support.zhoulinhua0.chatgpt.site/privacy`

如果当前页面看不到 Subtitle 或 Privacy Policy URL，不要担心：Subtitle 可能位于 iOS 版本页面；Privacy Policy URL 一定可以在 App Privacy 中填写。

### General Information

- Bundle ID：保持当前值，不要修改。
- SKU：已经创建后不可改，不需要处理。
- Primary Category：选择 **Health & Fitness**。
- Secondary Category：可选择 **Productivity**，也可以留空。
- Content Rights：选择 App **does not contain, show, or access third-party content**。
- License Agreement：保持 Apple Standard EULA，不需要自定义。

### Age Ratings

1. 点击 **Set Up Age Ratings**。
2. In-App Controls / Capabilities：RepDay 没有聊天、用户生成内容、网页浏览、广告或家长控制，全部按实际选择 No。
3. Content Descriptions：暴力、恐怖、色情、粗口、酒精/烟草/毒品、赌博、竞赛等均选 None。
4. RepDay 是普通健身记录工具，不提供医疗诊断或治疗建议；涉及医疗/健康声明的问题按这一事实填写。
5. Made for Kids：不要选择。
6. Override to Higher Age Rating：选择 **Not Applicable**。
7. Age Suitability URL：留空。
8. 点击 **Save**。系统预计会给出较低年龄分级；以系统最终计算结果为准。

## C. App Privacy（隐私营养标签）

路径：**RepDay → 左侧 General → App Privacy**。

### Privacy Policy

1. 在 Privacy Policy 旁点击 **Edit**。
2. Privacy Policy URL 填：  
   `https://repday-support.zhoulinhua0.chatgpt.site/privacy`
3. User Privacy Choices URL：留空。RepDay 没有账号和服务器端个人数据，无需单独的数据删除页面。
4. 点击 **Save**。

### Data Collection

1. 点击 **Get Started**。
2. 选择 **No, we do not collect data from this app**。
3. 点击 **Save**。
4. 如果页面要求发布隐私答案，点击 **Publish**。

代码审查依据：无网络请求、无账号、无第三方广告/分析 SDK；SwiftData、UserDefaults、App Group、EventKit 与本地通知均在用户设备上使用。

## D. Pricing and Availability（免费 + 仅美国）

路径：**RepDay → 左侧 Pricing and Availability**。

### Price

- Base Country or Region：可保持系统默认。
- Price：选择 **Free / 0.00**。

### App Availability

1. 点击 **Set Up Availability** 或 **Manage**。
2. 选择 **Specific Countries or Regions**。
3. 搜索并只勾选 **United States**。
4. 不要勾选自动加入未来新增国家或地区的选项。
5. 点击 **Next → Confirm**。

### Distribution Method

- 选择 **Public Distribution**。
- 不要选择 Private Distribution 或 Unlisted App。

### Mac / Vision Pro availability

如果页面提供“在 Apple silicon Mac 上提供 iPhone App”或“在 Apple Vision Pro 上提供 iPhone App”的选项，而你没有在这些设备上测试，首发建议取消勾选；这不影响 iPhone 美区上架。

## E. iOS Version 1.0.0 商品页

路径：**RepDay → 左侧 App Store / iOS App → 1.0.0 Prepare for Submission**。不同界面可能直接显示为 **1.0** 或版本号链接。

### App Previews and Screenshots

1. 找到 **iPhone 6.9" Display** 截图区。
2. 上传 1–10 张截图，建议 5 张。
3. RepDay 工程只支持 iPhone，因此不需要 iPad 截图。
4. 最稳妥的截图顺序：今日训练、动作/休息时间、每周计划、统计、模板或 Widget。

### Version Information

从 `Submission/AppStore_Metadata_EN.md` 复制：

- Promotional Text（可选）
- Description（必填）
- Keywords（必填）
- Support URL（必填）：  
  `https://repday-support.zhoulinhua0.chatgpt.site/support`
- Marketing URL（可选，建议填）：  
  `https://repday-support.zhoulinhua0.chatgpt.site`
- Version：保持 `1.0.0`
- Copyright：`2026 Linhua Zhou`

首次上架通常没有 What's New in This Version；如果页面显示，可留空。

### Build

1. 滚动到 **Build**。
2. 点击 **Select a build before you submit your app** 或右侧的 `+`。
3. 选择 `1.0.0 (2)`，不要选择 Build 1。
4. 如果出现 Export Compliance：RepDay 不包含自研或非豁免加密；工程已声明 `ITSAppUsesNonExemptEncryption = NO`。按页面实际问题选择不使用非豁免加密。
5. 点击 **Done**。

### App Review Information

- Sign-in required：No / 关闭。
- First Name：填写你的法定名字，例如 `Linhua`。
- Last Name：填写你的法定姓氏，例如 `Zhou`。
- Phone Number：填写审核期间能接听或收短信的真实电话，包含国家区号。
- Email：建议 `zhoulinhua0@gmail.com`。
- Notes：复制 `Submission/AppStore_Metadata_EN.md` 中的 **Review Notes**。
- Attachment：留空。

### App Store Version Release

选择 **Manually release this version**。这样审核通过后不会立刻上线，你可以最后检查商品页，再手动点 Release。

## F. Accessibility（如页面出现）

Accessibility Nutrition Labels 必须如实填写。只有你确实在最终 Build 2 中完整测试过某一项，才声明支持：

- VoiceOver：如果所有主要控件、训练流程、弹窗都能正确朗读和操作，才勾选。
- Larger Text、Dark Interface、Reduced Motion 等同理。
- 不确定的项目先不要声明；不要为了“看起来更完整”而过度承诺。

## G. 保存并提交

1. 在版本页面右上角点击 **Save**。
2. 检查页面上所有红色错误或黄色提示。
3. 确认 Build 显示 `1.0.0 (2)`。
4. 点击右上角 **Add for Review**。
5. 如果弹窗询问，创建新的 submission。
6. 打开左侧 **App Review** 或右下角 **Draft Submissions**。
7. 再检查一次提交项目，然后点击 **Submit for Review**。

只有完成最后一步，状态才会从 Ready for Review 进入 Waiting for Review / In Review。点击 Add for Review 本身还没有真正送审。

