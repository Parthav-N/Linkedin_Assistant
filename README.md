# LinkedIn Post Generator

A modern Flutter application that helps professionals create engaging LinkedIn posts with the power of AI.

![LinkedIn Post Generator Banner](https://via.placeholder.com/800x200/0077B5/FFFFFF?text=LinkedIn+Post+Generator)

## 🚀 Overview

LinkedIn Post Generator is a sleek, user-friendly application that transforms your ideas into polished LinkedIn posts. Whether you're sharing industry insights, professional achievements, or thought leadership content, this app helps you craft the perfect message to engage your professional network.

## ✨ Features

- **AI-Powered Content Generation**: Turn your basic ideas into well-structured LinkedIn posts
- **Real-time Editing**: Regenerate, reduce length, or elaborate on generated posts
- **One-Click Sharing**: Direct integration with LinkedIn for seamless posting
- **Intuitive UI**: Clean Material Design 3 interface for a smooth user experience
- **Offline Support**: Copy posts to clipboard when offline

## 🛠️ Technical Implementation

- **Frontend**: Built with Flutter for cross-platform compatibility
- **Backend**: RESTful API service hosted on Render
- **AI Integration**: Advanced natural language processing to generate relevant professional content
- **Error Handling**: Robust network error management with fallback options


## 🌐 Backend Configuration

The app connects to a backend service hosted on Render. If you want to run your own backend:

1. Clone the backend repository ([link to your backend repo](https://github.com/Parthav-N/Linkedin_Post_Generator_Backend))
2. Deploy it to your preferred hosting service
3. Update the `baseUrls` list in the `_makeNetworkRequest` method

## 🚨 Troubleshooting

- **Network Issues**: The app attempts to connect to multiple base URLs if one fails.
- **Timeout Errors**: Default timeout is set to 15 seconds, adjust as needed.
- **LinkedIn Integration**: Ensure the URL launcher package is properly configured for your platform.

## 🔮 Future Enhancements

- User authentication for personalized content
- Post templates for different LinkedIn content types
- Analytics to track post performance
- Dark mode support
- Post scheduling functionality

