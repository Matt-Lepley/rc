# Agent Regression Tester (ART)

ART is a Ruby-based tool designed to replicate common endpoint activities for testing and debugging purposes. It can perform actions related to processes, file operations, and network activities across different operating systems. ART also utilizes `EventLogger` which is responsible for recording and persisting all events generated during the testing process. It provides the following functionality:

- Records process, file, and network events with timestamps and relevant details
- Validates required attributes for each event type
- Logs events in both JSON and text formats
- Handles and logs errors that occur during the testing process

## Features

- Process execution simulation
- File operations (create, modify, delete)
- Network activity simulation (TCP, HTTP, UDP)
- Cross-platform support (Windows, macOS, Linux)
- Event logging in both JSON and text formats

## Requirements

- Ruby version: `>= 2.6.0`
- Operating Systems: Windows, macOS, or Linux
- Gems (only required for testing): `rspec`, `timecop`

## Installation

1. Clone this repository:

   ```
   git clone https://github.com/your-username/agent-regression-tester.git
   cd agent-regression-tester
   ```

2. The project uses only Ruby standard libraries for core functionality. If you want to run the test suite you will need to install the `rspec` and `timecop` gems.

## Usage

Run the script using Ruby:

```
ruby agent_regression_tester.rb [OPTIONS]
```

### Available Options:

- Process execution: `-p <process_name> [args]`
- File operations: `-f <path> <action> [content]`
- TCP connection: `-nt <host> <port>`
- HTTP request: `-nh <url>`
- UDP transmission: `-nu <data>`
- Run all tests: `--all`

### Examples:

#### Run individual tests

1. Execute a process:

   ```
   ruby agent_regression_tester.rb -p notepad.exe
   ```

2. Perform a file operation:

   ```
   ruby agent_regression_tester.rb -f tmp/test.txt create "Hello, World!"
   ```

3. Make a TCP connection:

   ```
   ruby agent_regression_tester.rb -nt example.com 80
   ```

4. Send an HTTP request:

   ```
   ruby agent_regression_tester.rb -nh http://example.com
   ```

5. Transmit UDP data:

   ```
   ruby agent_regression_tester.rb -nu "Test data"
   ```

#### Run all tests

```
ruby agent_regression_tester.rb --all
```

## Notes

This was developed with quite a few assumptions as the situation is hypothetical. Below are some reasons I took specific paths in the development of this project:

- **Data Validation:** Whitelisting processes and file actions is beneficial from both security and usability perspectives. Having predefined requirement attributes for logging ensures we always have the data we expect. This is crucial as a key focus for this program is to compare logs with another system.

- **CLI implementation:** I chose to go with a CLI implementation rather than a menu due to option to easily plug this into a different application. A menu would be more use friendly when running the program standalone, but would require a refactor to get it to work within another application.

- **Testing:** Testing was an additional _feature_ I added to ensure everything is working as intended and does not break functionality as changes are made.
