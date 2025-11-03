# Frontend Layer - UI & Presentation

This directory contains all frontend-related code for the Flutter mobile app:
- Screens/Pages
- Widgets/Components
- Theme & Styling

## Structure

```
frontend/
├── screens/           # Screen/Page widgets
│   ├── auth/         # Authentication screens
│   ├── dashboard/    # Dashboard screens
│   ├── leads/        # Lead management screens
│   ├── subscriptions/ # Subscription screens
│   └── territories/  # Territory screens
│
├── widgets/          # Reusable UI components
│   ├── common/       # Common widgets
│   ├── document_upload_dialog.dart
│   └── document_verification_page.dart
│
└── theme/            # Theme & styling (to be implemented)
```

## Organization

### Screens
- Each feature has its own folder
- Screens handle UI state and user interactions
- Call backend services for data operations

### Widgets
- Reusable UI components
- Stateless when possible
- Follow Flutter best practices

---

**Note**: All business logic should be in `backend/` folder

