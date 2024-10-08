#############
# Agent Regression Tester (ART)
#
# This script provides a way to replicate common endpoint activities for testing and debugging
# purposes. It's designed to assist in testing and debugging by allowing controlled execution of
# processes, file operations, and network activities.
#
# Usage:
#   ruby agent_regression_tester.rb [OPTIONS]
#
# Options:
#   -p <process_name> [args] : Execute a process
#   -f <path> <action> [content] : Perform a file operation
#   -nt <host> <port> : Make a TCP connection
#   -nh <url> : Send an HTTP request
#   -nu <data> : Transmit UDP data
#   --all : Run all tests
#

require "net/http"
require "shellwords"
require "socket"
require "time"
require 'fileutils'

require_relative "event_logger"

class AgentRegressionTester
  attr_reader :logger, :os, :username, :command

  VALID_FILE_ACTIONS = %w[create modify delete]
  VALID_WINDOWS_PROCESSES = %w[notepad.exe calc.exe mspaint.exe]
  VALID_LINUX_PROCESSES = %w[ls ps pwd]
  VALID_MAC_PROCESSES = %w[TextEdit Calculator]

  def initialize
    @logger = EventLogger.new
    @command = ([File.basename($PROGRAM_NAME)] + ARGV).shelljoin
    get_operating_system_and_username
  end

  def run
    command = ARGV[0]

    if command.nil?
      usage_output("Error: Must provide command argument.")
    end

    if command == "--all"
      run_all_commands
    else
      run_single_command
    end
  end

  private

  def get_operating_system_and_username
    @username = ENV["USER"] || ENV["LOGNAME"] || `whoami`.chomp

    case RUBY_PLATFORM
    when /darwin/i
      @os = "macOS"
    when /linux/i
      @os = "Linux"
    when /mswin|mingw|cygwin/i
      @os = "Windows"
      @username ||= ENV["USERNAME"]
    else
      @os = "Unknown"
    end
  end

  def usage_output(error = "")
    abort(<<~EOS
      #{error}

      Program:        ruby agent_regression_tester.rb -p  <path> <optional_args>
      File:           ruby agent_regression_tester.rb -f  <path> <action [create|modify|delete]> <content [optional]>
      Network (TCP):  ruby agent_regression_tester.rb -nt <host> <port>
      Network (HTTP): ruby agent_regression_tester.rb -nh <url>
      Network (UDP):  ruby agent_regression_tester.rb -nu <data>
      EOS
    )
  end

  def run_single_command
    command_arg, *args_array = ARGV

    if command_arg.nil?
      usage_output("Error: Must provide command argument.")
    end

    if command_arg == "-p"
      process_name, *args_array = *args_array

      if process_name.nil?
        usage_output("Error: Must provide process_name argument.")
      end

      valid_args = args_array.select { |arg| arg.include?("-") }
      invalid_args = args_array - valid_args

      puts "** Removed invalid args: #{invalid_args.to_s}" if invalid_args.any?

      execute_process(process_name, valid_args)
    elsif command_arg == "-f"
      path, action, content, *args_array = *args_array

      unless path && action && VALID_FILE_ACTIONS.include?(action)
        usage_output("Error: Must provide path and valid action. #{VALID_FILE_ACTIONS.to_s}")
      end

      handle_file_actions(path, action, content)
    elsif command_arg == "-nt"
      host, port, *args_array = *args_array

      if host.nil? || port.nil?
        usage_output("Error: Must provide host and port.")
      end

      tcp_connection(host, port)
    elsif command_arg == "-nh"
      url, *args_array = *args_array

      if url.nil?
        usage_output("Error: Must provide url.")
      end

      http_get_request(url)
    elsif command_arg == "-nu"
      data, *args_array = *args_array

      if data.nil?
        usage_output("Error: Must provie data.")
      end

      udp_transmission(data)
    else
      usage_output("Error: Unknown command.")
    end
  end

  def run_all_commands
    test_file = "tesing_file.txt"

    # Process testing
    if @os == "Windows"
      execute_process("notepad.exe")
    elsif @os == "macOS"
      execute_process("TextEdit")
    elsif @os == "Linux"
      execute_process("ls", ["-la"])
    else
      raise "Unable to detect OS, received #{RUBY_PLATFORM} as platform."
    end

    # File operation testing
    puts "* Testing file operations..."
    handle_file_actions(test_file, "create", "Test content")
    handle_file_actions(test_file, "modify")
    handle_file_actions(test_file, "delete")

    # Network testing
    puts "* Performing network tests..."
    tcp_connection("example.com", 80)
    http_get_request("http://example.com")
    udp_transmission("DNS Test")
  end

  def execute_process(process_name, args = [])
    case @os
    when "macOS"
      unless VALID_MAC_PROCESSES.include?(process_name)
        usage_output("Error: Must provide valid process name. #{VALID_MAC_PROCESSES.to_s}")
      end

      os_command = ["open -a", process_name, args].join(" ").strip
    when "Linux"
      unless VALID_LINUX_PROCESSES.include?(process_name)
        usage_output("Error: Must provide valid process name. #{VALID_LINUX_PROCESSES.to_s}")
      end

      os_command = [process_name, args].join(" ").strip
    when "Windows"
      unless VALID_WINDOWS_PROCESSES.include?(process_name)
        usage_output("Error: Must provide valid process name. #{VALID_WINDOWS_PROCESSES.to_s}")
      end

      os_command = ["start", process_name, args].join(" ").strip
    end

    process = IO.popen(os_command)

    @logger.record_process_event(
      timestamp: Time.now.iso8601,
      username:,
      process_name: File.basename(process_name),
      process_command: @command,
      process_id: process.pid,
    )

    # Don't leave process running, force kill
    Process.kill("KILL", process.pid)
  rescue => e
    @logger.record_logging_error(e.message)
  end

  # NOTE: Testing directories for readonly
  #
  # /var/log/syslog - windows
  # /etc/passwd - linux/mac
  def handle_file_actions(file_path, action, content = nil)
    if ["modify", "delete"].include?(action) && !File.exist?(file_path)
      abort("File ['#{file_path}'] does not exist")
    end

    content ||= "Test data"

    case action
    when "create"
      dir_path = File.dirname(file_path)

      unless Dir.exist?(dir_path)
        FileUtils.mkdir_p(dir_path)
        puts "**Created directory: #{dir_path}"
      end

      File.write(file_path, content)

    when "modify"
      if !File.stat(file_path).writable?
        abort("File ['#{file_path}'] is not writable")
      end

      File.open(file_path, "a") { |f| f.puts("\n#{content}\nModified: #{Time.now}") }
    when "delete"
      File.delete(file_path)
    end

    @logger.record_file_event(
      timestamp: Time.now.iso8601,
      username:,
      process_name: File.basename($PROGRAM_NAME),
      process_command: @command,
      process_id: Process.pid,
      file_path: File.expand_path(file_path),
      activity: action
    )
  rescue => e
    @logger.record_logging_error(e.message)
  end

  def tcp_connection(host, port)
    begin
      socket = TCPSocket.new(host, port, connect_timeout: 5)
    rescue Errno::ETIMEDOUT
      usage_output("Failed to establish connection. Make sure host and port are valid.")
    end

    data = "GET / HTTP/1.0\r\nHost: #{host}\r\n\r\n"
    socket.write(data)

    @logger.record_network_event(
      timestamp: Time.now.iso8601,
      username:,
      process_name: File.basename($PROGRAM_NAME),
      process_command: @command,
      process_id: Process.pid,
      protocol: "TCP",
      data_in_bytes: data.bytesize,
      destination_addr: host,
      destination_port: port,
      source_addr: socket.local_address.ip_address,
      source_port: socket.local_address.ip_port
    )
  rescue => e
    @logger.record_logging_error(e.message)
  ensure
    socket&.close
  end

  # NOTE: only supports http
  def http_get_request(url)
    uri = URI(url)

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri)
    local_conn = {}

    http.start do |conn|
      conn.request(request)

      socket = conn.instance_variable_get(:@socket).io

      local_conn[:host] = socket.local_address.ip_address
      local_conn[:port] = socket.local_address.ip_port
    end

    @logger.record_network_event(
      timestamp: Time.now.iso8601,
      username:,
      process_name: File.basename($PROGRAM_NAME),
      process_command: @command,
      process_id: Process.pid,
      protocol: "HTTP",
      data_in_bytes: request.body&.bytesize || 0,
      destination_addr: uri.host,
      destination_port: uri.port,
      source_addr: local_conn[:host],
      source_port: local_conn[:port]
    )
  rescue => e
    @logger.record_logging_error(e.message)
  end

  # NOTE: socket local_address returns 0.0.0.0
  def udp_transmission(data)
    host = "8.8.8.8"
    port = 53
    socket = UDPSocket.new
    bytes_sent = socket.send(data, 0, host, port)

    @logger.record_network_event(
      timestamp: Time.now.iso8601,
      username:,
      process_name: File.basename($PROGRAM_NAME),
      process_command: @command,
      process_id: Process.pid,
      protocol: "UDP",
      data_in_bytes: bytes_sent,
      destination_addr: host,
      destination_port: port,
      source_addr: socket.local_address.ip_address,
      source_port: socket.local_address.ip_port
    )
  rescue => e
    @logger.record_logging_error(e.message)
  ensure
    socket&.close
  end
end

# Run
if __FILE__ == $PROGRAM_NAME
  tester = AgentRegressionTester.new

  begin
    puts "\n\n🎨 Starting ART... 🎨"
    puts "* OS Detected: #{tester.os}"

    tester.run
    tester.logger.persist_logs

    puts "* Testing completed. Check the log files for results."
  rescue => e
    puts "Error during testing: #{e.message}"
  end
end
