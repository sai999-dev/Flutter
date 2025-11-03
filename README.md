# Healthcare Leads Mobile App

A comprehensive Flutter mobile/web application for healthcare agencies to manage leads, service areas, and subscriptions.

## ✨ Features

### 🎯 Core Features
- **📍 Live Location Detection** - Auto-detect zipcode from GPS
- **👥 Lead Management** - View, filter, and manage healthcare leads
- **📞 Click-to-Call & Email** - Direct integration with phone/email
- **📝 Notes & Status Tracking** - Add notes and update lead status
- **📊 Export to CSV** - Export filtered leads to CSV file
- **✅ Bulk Actions** - Select multiple leads for batch operations
- **📊 Dashboard** - View service areas and quick stats
- **💳 Subscription Management** - 4 plans: Basic, Growth, Professional, Enterprise
- **⚙️ Settings** - Profile, service areas, and payment management

### 💡 Lead Features
- Real-time data from HospiceConnect database
- Advanced filtering (Priority, Status, Search)
- Lead quality scoring (Hot/Warm/Cold)
- Estimated value per lead
- Contact information and location
- Status workflow management

### 📍 Service Area Management
- Add zipcodes via live location
- Quick select from popular areas
- Manual zipcode entry with city detection
- Plan-based area limits
- Real-time updates

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.0.0+)
- Dart SDK
- Chrome (for web testing)
- HospiceConnect Backend running on `http://127.0.0.1:4002`

### Installation

```bash
# Clone the repository
cd Flutter

# Install dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome --web-port 8080

# Or run on mobile device
flutter run
```

## 📱 Usage

### Login
Default credentials (demo):
- Email: `admin@example.com`
- Password: `password123`

### Tabs
1. **Leads** - Manage all your leads
2. **Dashboard** - View service areas and stats
3. **Plans** - Manage subscription
4. **Settings** - Profile and preferences

### Lead Actions
- **📞 Call** - Click green phone icon
- **📧 Email** - Click blue email icon
- **ℹ️ Details** - Click info icon for full details
- **✅ Select** - Click checklist icon for bulk actions

## 🗂️ Project Structure

```
Flutter/
├── lib/
│   └── main.dart          # All app code (clean, single file)
├── assets/
│   ├── icons/             # App icons
│   ├── images/            # Images
│   └── dallas_specific_areas.json
├── android/               # Android build files
├── ios/                   # iOS build files
├── web/                   # Web build files
├── pubspec.yaml           # Dependencies
└── README.md             # This file
```

## 📦 Dependencies

### Core
- `flutter` - UI framework
- `http` - API calls
- `shared_preferences` - Local storage

### Features
- `geolocator` - Location detection
- `geocoding` - Address from coordinates
- `url_launcher` - Call/email integration
- `csv` - Export functionality
- `path_provider` - File system access
- `share_plus` - Share files

### UI
- `google_fonts` - Typography
- `flutter_svg` - Vector graphics

## 🔧 Configuration

### Backend Connection
Update the API endpoint in `main.dart`:
```dart
final response = await http.get(
  Uri.parse('http://127.0.0.1:4002/api/submissions')
);
```

### Subscription Plans
Modify plans in `SubscriptionPage`:
- **Basic**: $99/month - 3 areas
- **Growth**: $199/month - 7 areas
- **Professional**: $299/month - 15 areas
- **Enterprise**: $599/month - 30 areas

## 🎨 Color Scheme
- **Primary**: `#667eea` (Purple)
- **Success**: `#10B981` (Green)
- **Warning**: `#FF6B35` (Orange)
- **Info**: `#667eea` (Blue)
- **Premium**: `#8B5CF6` (Purple)

## 📄 License
Copyright © 2025 Healthcare Leads App. All rights reserved.

## 🤝 Support
For support and questions, contact your system administrator.

---

**Version**: 1.0.0  
**Last Updated**: October 26, 2025  
**Status**: Production Ready ✅
