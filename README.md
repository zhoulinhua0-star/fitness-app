# 🏋️ FitnessApp

![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Xcode](https://img.shields.io/badge/Xcode-15.0%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

A minimalist, efficient, and native iOS workout schedule management app built with SwiftUI.

Say goodbye to tedious modal pop-ups. FitnessPlan features WYSIWYG (What You See Is What You Get) inline editing and a Bento Box design, allowing you to seamlessly and intelligently sync your workout plan to the iPhone system calendar with a single tap.

## ✨ Features

* 🍱 **Bento Box UI & Intensity Heatmap**: The home page uses Apple's native Bento layout and automatically generates an intensity progress bar (Moderate / High-Burn / Extreme) based on your daily training volume (total sets), making your workout intensity clear at a glance.
* ⚡️ **Lightning-Fast Inline Editing**: Completely ditches traditional `.sheet` pop-ups. All exercise names, sets, and reps are modified directly in the list, automatically saving in real-time via `@Bindable`.
* 🗓️ **Smart Calendar Sync**: Built with `EventKit`, sync your workout schedule to the iOS system calendar with one tap. It uses a "smart overwrite" strategy to ensure no duplicate events are created, even if you sync multiple times.
* 📋 **Efficiency Scheduling Tools**: Supports one-tap clearing of daily exercises or "cloning" a workout from another date, drastically reducing repetitive input.
* 🔋 **100% Local Execution**: Powered by the latest `SwiftData`. Zero network requests and no background refreshing, ensuring ultimate battery saving and data privacy.

## 📸 Screenshots

<p align="center">
  <img src="https://github.com/user-attachments/assets/034d4c3a-c752-475e-9251-66e40a91d729" width="250" />
  <img src="https://github.com/user-attachments/assets/faef0913-24de-44ac-ab78-4d7c2e3e8acc" width="250" />
  <img src="https://github.com/user-attachments/assets/310ef9a2-69e1-47ee-a4cd-0526a50ffc2a" width="250" />
</p>

## 🛠️ Tech Stack

* **iOS 17.0+**
* **UI Framework**: SwiftUI
* **Local Storage**: SwiftData
* **System Interaction**: EventKit (Calendar Sync) / UIFeedbackGenerator (Haptics)

## 🚀 Getting Started

1. Clone this repository to your local machine:
   ```bash
   git clone [https://github.com/zhoulinhua0-star/fitness-app.git](https://github.com/zhoulinhua0-star/fitness-app.git)
   ```
          
2. Open the .xcodeproj file using Xcode 15 or later.
              
3. Configure your Apple Developer account in Signing & Capabilities.

4. Build and run on an iOS 17 Simulator or physical device.

* **Note: The calendar sync feature works best on a physical device. It will request calendar access upon the first sync; please select "Allow Full Access".

## 🤝 Contributing

Contributions, issues, and feature requests are highly welcome!
If you want to contribute:

1. Fork the project.

2. Create your feature branch (git checkout -b feature/AmazingFeature).

3. Commit your changes (git commit -m 'Add some AmazingFeature').

4. Push to the branch (git push origin feature/AmazingFeature).

5. Open a Pull Request.

## 🤝 License

This project is licensed under the MIT License. Whether for personal learning, secondary development, or commercial use, feel free to use it! Pull requests and feature suggestions are always welcome.
