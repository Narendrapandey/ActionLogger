ActionLogger
A Swift-based library designed to log user actions within your application, enhancing user behavior analysis and debugging processes.

Features

Efficient logging of user interactions.
Lightweight and easy to integrate.
Customizable to fit various logging needs.
Installation
Swift Package Manager
To include ActionLogger in your project, add the following dependency to your Package.swift file:
.package(url: "https://github.com/Narendrapandey/ActionLogger.git", from: "1.0.0")
Then, add "ActionLogger" to your target's dependencies.
Usage
Import the library where you need to log actions:
import ActionLogger
To log an action:
ActionLogger.log("User tapped on the 'Submit' button")
This will record the action with a timestamp and description.
Configuration
Customize the logging behavior by modifying the ActionLogger settings:
ActionLogger.settings.logLevel = .verbose
ActionLogger.settings.destination = .file("logs/user_actions.log")
This example sets the log level to verbose and specifies a file destination for the logs.
Contribution
Contributions are welcome! Please fork the repository, create a new branch, and submit a pull request with your proposed changes.
