require "socket"
require "securerandom"
require "net/http"
require "etc"

require_relative "telemetry_logger"

class AgentRegressionTester
  attr_reader :os, :logger

  def initialize
    @logger = TelemetryLogger.new
    @os = get_operating_system
  end

  def execute_monitored_process(executable_path, args = [])
    command = [executable_path, *args].join(" ")
    process = IO.popen(command)

    puts "OS: #{@os}"

    @logger.record_event(
      "process_execution",
      executable: File.basename(executable_path),
      command_line: command,
      pid: process.pid
    )

    process
  rescue => e
    @logger.record_event("process_execution_error", error: e.message)
    raise
  end

  def manipulate_test_file(file_path, action, content = nil)
    case action
    when "create"
      File.write(file_path, content || "")
    when "modify"
      File.open(file_path, "a") { |f| f.puts("\nModified: #{Time.now}") }
    when "delete"
      File.delete(file_path)
    end

    @logger.record_event(
      "filesystem_activity",
      target_path: file_path,
      operation: action,
      process_name: File.basename($PROGRAM_NAME),
      pid: Process.pid
    )
  rescue => e
    @logger.record_event("filesystem_error", error: e.message)
    raise
  end

  # Network testing methods
  def test_tcp_connection(host, port)
    socket = TCPSocket.new(host, port)
    local_addr = socket.local_address

    @logger.record_event(
      "network_tcp_connection",
      destination_host: host,
      destination_port: port,
      source_address: local_addr.ip_address,
      source_port: local_addr.ip_port
    )
  ensure
    socket&.close
  end

  def test_http_get_request(url)
    uri = URI(url)
    response = Net::HTTP.get_response(uri)

    @logger.record_event(
      "network_http_get",
      url: url,
      response_code: response.code,
      response_body_size: response.body.size,
      headers_sent: response.uri.to_s
    )
  end

  def test_udp_transmission(host, port, data)
    socket = UDPSocket.new
    bytes_sent = socket.send(data, 0, host, port)

    @logger.record_event(
      "network_udp_transmission",
      destination_host: host,
      destination_port: port,
      bytes_transmitted: bytes_sent,
      source_port: socket.local_address.ip_port
    )
  ensure
    socket&.close
  end

  def simulate_various_network_activities
    # This method demonstrates various network activities for EDR testing
    {
      tcp_ports: [80, 443, 8080],
      udp_ports: [53, 123],
      hosts: ["example.com", "google.com"]
    }.each do |protocol, targets|
      targets.each do |target|
        case protocol
        when :tcp_ports
          test_tcp_connection("example.com", target)
        when :udp_ports
          test_udp_transmission("example.com", target, "Test UDP packet")
        when :hosts
          test_http_get_request("https://#{target}")
        end
      end
    end
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

# Implementation example
if __FILE__ == $PROGRAM_NAME
  tester = AgentRegressionTester.new
  test_file = "tmp/telemetry_test_#{SecureRandom.uuid}.txt"

  begin
    puts "Starting EDR Telemetry Test Suite"

    # Process testing
    if RUBY_PLATFORM =~ /mswin|mingw|windows/
      tester.execute_monitored_process("notepad.exe")
    else
      tester.execute_monitored_process("/bin/ls", ["-l"])
      tester.execute_monitored_process("cat tmp/todo.txt")
    end

    # File operation testing
    puts "Testing file operations..."
    tester.manipulate_test_file(test_file, "create", "Test content")
    tester.manipulate_test_file(test_file, "modify")
    tester.manipulate_test_file(test_file, "delete")

    # Network testing

    # Individual network tests
    puts "Performing network tests..."
    tester.test_tcp_connection("example.com", 80)
    tester.test_http_get_request("https://example.com")
    tester.test_udp_transmission("8.8.8.8", 53, "DNS query simulation")

    # Persist logs
    tester.logger.persist_logs
    puts "Testing completed. Check the log files for results."

  rescue => e
    puts "Error during telemetry testing: #{e.message}"
    exit 1
  end
end