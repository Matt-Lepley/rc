require "timecop"
require_relative "../event_logger"

# Suppress error output to console
RSpec.configure do |c|
  c.before { allow($stderr).to receive(:write) }
end

RSpec.describe EventLogger do
  let(:json_log_file) { "test_json_log.json" }
  let(:text_log_file) { "test_text_log.log" }
  let(:logger) { EventLogger.new(json_log_file: json_log_file, text_log_file: text_log_file) }

  after do
    File.delete(json_log_file) if File.exist?(json_log_file)
    File.delete(text_log_file) if File.exist?(text_log_file)
  end

  describe "#record_process_event" do
    let(:event) do
      {
        timestamp: Time.now.iso8601,
        username: "testuser",
        process_name: "test_process",
        process_command: "test_command",
        process_id: 1234
      }
    end

    it "records a process event" do
      Timecop.freeze(Time.now) do
        expect { logger.record_process_event(**event) }.not_to raise_error
        expect(logger.instance_variable_get(:@events)).to include(event)
      end
    end

    it "records a logging error" do
      expect { logger.record_process_event(**{}) }.to raise_error(SystemExit, /Ensure you have provided all attributes.*:timestamp/)
    end
  end

  describe "#record_file_event" do
    let(:event) do
      {
        timestamp: Time.now.iso8601,
        username: "testuser",
        process_name: "test_process",
        process_command: "test_command",
        process_id: 1234,
        file_path: "/test/path",
        activity: "create"
      }
    end

    it "records a file event" do
      Timecop.freeze(Time.now) do
        expect { logger.record_file_event(**event) }.not_to raise_error
        expect(logger.instance_variable_get(:@events)).to include(event)
      end
    end

    it "records a logging error" do
      expect { logger.record_file_event(**{}) }.to raise_error(SystemExit, /Ensure you have provided all attributes.*:activity/)
    end
  end

  describe "#record_network_event" do
    let(:event) do
      {
        timestamp: Time.now.iso8601,
        username: "testuser",
        process_name: "test_process",
        process_command: "test_command",
        process_id: 1234,
        protocol: "TCP",
        data_in_bytes: 100,
        destination_addr: "192.168.1.1",
        destination_port: 80,
        source_addr: "127.0.0.1",
        source_port: 12345
      }
    end

    it "records a network event" do
      Timecop.freeze(Time.now) do
        expect { logger.record_network_event(**event) }.not_to raise_error
        expect(logger.instance_variable_get(:@events)).to include(event)
      end
    end

    it "records a logging error" do
      expect { logger.record_network_event(**{}) }.to raise_error(SystemExit, /Ensure you have provided all attributes.*:source_port/)
    end
  end

  describe "#record_logging_error" do
    let(:error_message) { "Test error" }

    it "records an error and aborts" do
      expect { logger.record_logging_error(error_message) }.to raise_error(SystemExit)
      expect(logger.instance_variable_get(:@events)).to include({ error: error_message })
    end
  end

  describe "#persist_logs" do
    let(:event) { { test: "event" } }

    it "writes events to JSON file" do
      logger.instance_variable_get(:@events) << event
      logger.persist_logs

      expect(File.exist?(json_log_file)).to be true
    end
  end
end