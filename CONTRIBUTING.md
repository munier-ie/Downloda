# Contributing to Downloda

We welcome contributions of all kinds to Downloda. As an open-source project, Downloda thrives on community collaboration. This document outlines the procedures and standards for contributing to this repository.

---

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please report any unacceptable behavior to the project maintainers.

---

## How to Contribute

### Reporting Bugs
* Check the existing issues to ensure the bug has not already been reported.
* Open a new issue with a clear, descriptive title.
* Provide a minimal reproduction recipe, including:
  * Android OS version and device architecture.
  * Flutter environment details (`flutter doctor -v`).
  * Expected behavior vs. actual behavior.
  * Relevant stack traces or logcat output.

### Suggesting Enhancements
* Open an issue outlining the proposed feature.
* Explain the use case and why this enhancement is valuable to the broader user base.
* Provide mockups or design outlines if the feature involves UI changes.

### Submitting Pull Requests
1. Fork the repository and create a new branch from `main`.
2. Ensure your branch name is descriptive (e.g., `feature/add-mp4-metadata` or `bugfix/fix-drift-migration`).
3. Make your changes, ensuring you follow our coding standards.
4. Verify your changes compile and pass all tests.
5. Submit a pull request targeting the `main` branch.
6. Provide a detailed summary of your changes in the pull request description.

---

## Developer Setup and Guidelines

### Setting Up the Environment
1. Clone the repository:
   ```bash
   git clone https://github.com/munier-ie/Downloda.git
   cd Downloda
   ```
2. Retrieve dependencies:
   ```bash
   flutter pub get
   ```

### Code Generation
This project uses Drift for reactive local persistence. If you modify any database schemas or tables in `lib/core/database/tables.dart`, you must regenerate the database code by running:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Coding Standards
* Run the Flutter formatter on all Dart code before committing:
  ```bash
  flutter format lib/
  ```
* Ensure your code passes static analysis with no warnings or errors:
  ```bash
  flutter analyze
  ```
* Adhere to the styles specified in `analysis_options.yaml`. Keep components modular, reusable, and separate logic from UI layer.

---

## Testing

Before submitting a pull request, run the test suite to ensure no regressions are introduced:
```bash
flutter test
```
