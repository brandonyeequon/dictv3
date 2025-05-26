# Japanese Dictionary App

A mobile application developed using Flutter, designed to serve as a comprehensive Japanese-English dictionary. It allows users to search for Japanese words using text input or handwriting recognition and view detailed information including kanji, kana, English meanings, and more. The app also includes a learning section to help users study Japanese vocabulary.

## Core Features

This application offers a range of features to assist users in their Japanese language learning journey:

*   **Comprehensive Dictionary Search:**
    *   **Text Input:** Quickly search for Japanese words using English, Japanese (Kanji, Hiragana, Katakana), or Romaji.
    *   **Handwriting Recognition:** Input Japanese characters by drawing them on the screen, powered by Google's ML Kit. Recognized characters are automatically added to the search bar.
*   **Detailed Word Information:** For each word, the app displays:
    *   Kanji representation.
    *   Hiragana/Katakana readings.
    *   Furigana (where applicable).
    *   Multiple English meanings.
    *   Romaji transliteration.
    *   JLPT (Japanese Language Proficiency Test) level indicators and priority points, which influence search result ranking.
    *   Other relevant tags and data from the underlying dictionary database.
*   **Interactive Search Results:**
    *   Results are displayed in an expandable list format.
    *   Users can tap on a word to see more details or navigate to a dedicated word detail page.
*   **Learning Section:**
    *   Includes a dedicated "Learn" tab, providing users with tools and resources to study Japanese vocabulary. (Further details about this section will be added as it's developed/explored).
*   **Offline Access:**
    *   The dictionary database is stored locally on the device, allowing for offline access once the initial setup (including ML model download) is complete.

## Technical Details

This application is built with modern technologies to provide a robust and efficient user experience:

*   **Framework:** Developed using [Flutter](https://flutter.dev/), Google's UI toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase.
*   **Database:**
    *   Utilizes a local [SQLite](https://www.sqlite.org/index.html) database (`V6.db`) to store the dictionary data. This database is bundled with the application and copied to the user's device on first launch.
    *   Employs [FTS5](https://www.sqlite.org/fts5.html) (Full-Text Search version 5) for fast and efficient searching of Japanese words and their meanings.
*   **Key Dependencies:**
    *   `google_mlkit_digital_ink_recognition`: Integrates Google's ML Kit for on-device Japanese handwriting recognition.
    *   `sqlite3` / `sqlite3_flutter_libs`: Provides SQLite database support for Flutter.
    *   `path_provider` & `path`: Used for locating and managing the database file path on the device.
    *   `provider`: For state management within the application.
    *   `flutter_drawing_board`: Powers the canvas used for handwriting input.

## Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

*   **Flutter SDK:** Ensure you have the Flutter SDK installed. You can find installation instructions on the [official Flutter website](https://docs.flutter.dev/get-started/install).
*   **IDE:** An IDE like Android Studio (with Flutter plugin) or Visual Studio Code (with Flutter extension) is recommended.

### Installation & Running

1.  **Clone the repository / Navigate to Project Directory:**
    ```bash
    # If you have cloned this repository from a version control system (e.g., GitHub):
    # git clone <repository_url>
    # cd <repository_directory_name>
    #
    # If you have the project files locally, simply navigate to the project root directory.
    cd <project_directory_name>
    ```
    (Navigate to the root directory of the project if you haven't already)

2.  **Get Flutter packages:**
    ```bash
    flutter pub get
    ```

4.  **Run the application:**
    ```bash
    flutter run
    ```
    This command will build and run the application on a connected device or emulator.

### First Run

*   **ML Model Download:** On the first launch of the application, it will automatically check for and download the Japanese language model required for handwriting recognition if it's not already present on your device. This may take a few moments depending on your internet connection.
*   **Database Setup:** The application will also copy the bundled SQLite database to the appropriate local directory on your device.

## Project Structure

Here's an overview of the key directories and files within the project:

```
.
├── android/              # Android specific files
├── assets/
│   └── V6.db             # Bundled SQLite dictionary database
├── ios/                  # iOS specific files
├── lib/                  # Main Dart code for the application
│   ├── main.dart         # Entry point of the application, main UI structure
│   ├── database_helper.dart # Manages SQLite database interactions (CRUD, FTS)
│   ├── japanese_word.dart # Data model for Japanese words
│   ├── japanese_recognition_page.dart # UI and logic for handwriting recognition
│   ├── word_detail_page.dart # UI for displaying detailed word information
│   └── learn_page.dart   # UI and logic for the learning section
├── linux/                # Linux specific files (if supported)
├── macos/                # macOS specific files (if supported)
├── test/                 # Widget and unit tests
├── web/                  # Web specific files (if supported)
├── windows/              # Windows specific files (if supported)
└── pubspec.yaml          # Project metadata, dependencies, and asset declarations
```

*   `lib/`: Contains all the Dart code for the application's logic and UI.
    *   `main.dart`: Initializes the app, sets up routing, and contains the main home page (`MyHomePage`).
    *   `database_helper.dart`: A crucial class responsible for managing the SQLite database, including copying it from assets, performing search queries (utilizing FTS5), and retrieving word data.
    *   `japanese_word.dart`: Defines the `JapaneseWord` class, which models the data structure for dictionary entries.
    *   `japanese_recognition_page.dart`: Implements the UI for the drawing canvas and integrates with the `google_mlkit_digital_ink_recognition` package for Japanese handwriting input.
    *   `word_detail_page.dart`: Displays comprehensive details for a selected Japanese word.
    *   `learn_page.dart`: Contains the features and UI for the "Learn" section of the app.
*   `assets/`: Stores static assets bundled with the application.
    *   `V6.db`: The pre-populated SQLite database containing the Japanese-English dictionary data.
*   `pubspec.yaml`: Defines project settings, dependencies (like Flutter SDK, `provider`, `sqlite3`, `google_mlkit_digital_ink_recognition`), and declares assets like the database file.
*   Platform-specific directories (`android/`, `ios/`, etc.): Contain platform-specific configuration and code.

## Contributing

Contributions are welcome! If you have suggestions for improvements or new features, please feel free to:

1.  Fork the Project.
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the Branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

Alternatively, you can open an issue with the tag "enhancement".

Please make sure to update tests as appropriate.
