require "socket"
require "securerandom"
require "net/http"
require "etc"

require_relative "event_logger"

class AgentRegressionTester
  attr_reader :os, :logger

  VALID_FILE_ACTIONS = %w[create modify delete]

  def initialize
    @logger = EventLogger.new
    @os = get_operating_system
  end

  def usage_output
    abort(<<~EOS

      Program:        ruby agent_regression_tester.rb -p  <path> <optional_args>
      File:           ruby agent_regression_tester.rb -f  <path> <action [create|modify|delete]> <content [optional]>
      Network (TCP):  ruby agent_regression_tester.rb -nt <host> <port>
      Network (HTTP): ruby agent_regression_tester.rb -nh <url>
      Network (UDP):  ruby agent_regression_tester.rb -nu <data>
      EOS
    )
  end

  def run
    command = ARGV[0]

    if command.nil?
      puts "Error: Must provide command argument."
      usage_output
    end

    if command == "--all"
      test_all
    else
      test_individual
    end
  end

  def test_individual
    command, *args_array = ARGV

    if command.nil?
      puts "Error: Must provide command argument."
      usage_output
    end

    if command == "-p"
      path, *args_array = *args_array

      if path.nil?
        puts "Error: Must provide path argument."
        usage_output
      end

      valid_args = args_array.select { |arg| arg.include?("-") }
      invalid_args = args_array - valid_args

      puts "** Removed invalid args: #{invalid_args.to_s}" if [invalid_args].any?

      execute_process(path, valid_args)
    elsif command == "-f"
      path, action, content, *args_array = *args_array

      unless path && action && VALID_FILE_ACTIONS.include?(action)
        puts "Error: Must provide path and valid action. #{VALID_FILE_ACTIONS.to_s}"
        usage_output
      end

      handle_file_actions(path, action, content)
    elsif command == "-nt"
      host, port, *args_array = *args_array

      if host.nil? || port.nil?
        puts "Error: Must provide host and port."
        usage_output
      end

      tcp_connection(host, port)
    elsif command == "-nh"
      url, *args_array = *args_array

      if url.nil?
        puts "Error: Must provide url."
        usage_output
      end

      http_get_request(url)
    elsif command == "-nu"
      data, *args_array = *args_array

      if data.nil?
        puts "Error: Must provie data."
        usage_output
      end

      udp_transmission(data)
    else
      puts "Error: Unknown command."
      usage_output
    end
  end

  def test_all
    test_file = "telemetry_test_#{SecureRandom.uuid}.txt"

    # Process testing
    if @os == "Windows"
      execute_process("notepad.exe")
    elsif @os == "macOS"
      execute_process("/bin/ls", ["-la"])
    elsif @os == "Linux"
      execute_process("/bin/ls", ["-la"])
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

  def execute_process(file_path, args)
    command = [file_path, args].join(" ")
    process = IO.popen(command)

    @logger.record_event(
      "process_execution",
      process_name: File.basename(file_path),
      command_line: command,
      pid: process.pid
    )

    process
  rescue => e
    @logger.record_event("process_execution_error", error: e.message)
    raise
  end

  def handle_file_actions(file_path, action, content = nil)
    content ||= "Test data"

    case action
    when "create"
      File.write(file_path, content)
    when "modify"
      File.open(file_path, "a") { |f| f.puts("\n#{content}\nModified: #{Time.now}") }
    when "delete"
      File.delete(file_path)
    end

    @logger.record_event(
      "filesystem_activity",
      target_path: File.expand_path(file_path),
      activity: action,
      process_name: File.basename($PROGRAM_NAME),
      pid: Process.pid
    )
  rescue => e
    @logger.record_event("filesystem_error", error: e.message)
    raise
  end

  def tcp_connection(host, port)
    begin
      socket = TCPSocket.new(host, port, connect_timeout: 5)
    rescue Errno::ETIMEDOUT
      puts "Failed to establish connection. Make sure host and port are valid."
      usage_output
    end

    data = "GET / HTTP/1.0\r\nHost: #{host}\r\n\r\n"
    socket.write(data)

    @logger.record_event(
      "network_tcp_connection",
      protocol: "TCP",
      destination_host: host,
      destination_port: port,
      bytes_transmitted: data.bytesize,
      source_address: socket.local_address.ip_address,
      source_port: socket.local_address.ip_port,
      process_name: File.basename($PROGRAM_NAME),
      pid: Process.pid
    )
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

    @logger.record_event(
      "network_http_get",
      protocol: "HTTP",
      destination_host: uri.host,
      destination_port: uri.port,
      bytes_transmitted: request.body&.bytesize || 0,
      source_address: local_conn[:host],
      source_port: local_conn[:port],
      process_name: File.basename($PROGRAM_NAME),
      pid: Process.pid
    )
  end

  # NOTE: socket local_address returns 0.0.0.0
  def udp_transmission(data)
    host = "8.8.8.8"
    port = 53
    socket = UDPSocket.new
    bytes_sent = socket.send(data, 0, host, port)

    @logger.record_event(
      "network_udp_transmission",
      protocol: "UDP",
      destination_host: host,
      destination_port: port,
      bytes_transmitted: bytes_sent,
      source_address: socket.local_address.ip_address,
      source_port: socket.local_address.ip_port,
      process_name: File.basename($PROGRAM_NAME),
      pid: Process.pid
    )
  ensure
    socket&.close
  end

  private

  def get_operating_system
    case RUBY_PLATFORM
    when /darwin/i
      "macOS"
    when /linux/i
      "Linux"
    when /mswin|mingw|cygwin/i
      "Windows"
    else
      "Unknown"
    end
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
    puts "Error during telemetry testing: #{e.message}"
  end
end