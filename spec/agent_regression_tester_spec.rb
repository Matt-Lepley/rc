require_relative "../agent_regression_tester"

# Suppress error output to console
RSpec.configure do |c|
  c.before { allow($stderr).to receive(:write) }
end

RSpec.describe AgentRegressionTester do
  let(:tester) { AgentRegressionTester.new }

  describe "#initialize" do
    it "sets up logger, os, username, and command" do
      expect(tester.logger).to be_a(EventLogger)
      expect(tester.os).to be_a(String)
      expect(tester.username).to be_a(String)
      expect(tester.command).to be_a(String)
    end
  end

  describe "#run" do
    context "when no command is provided" do
      it "outputs an error message and usage information" do
        allow(ARGV).to receive(:[]).with(0).and_return([])
        expect { tester.run }.to raise_error(SystemExit, /Must provide command argument./)
      end
    end

    context "when --all command is provided" do
      it "calls run_all_commands" do
        allow(ARGV).to receive(:[]).with(0).and_return("--all")
        expect(tester).to receive(:run_all_commands)

        tester.run
      end
    end

    context "when a single command is provided" do
      it "calls run_single_command" do
        allow(ARGV).to receive(:[]).with(0).and_return("-p")
        expect(tester).to receive(:run_single_command)

        tester.run
      end
    end
  end

  describe "#execute_process" do
    context "macOS" do
      it "successfully records a process event" do
        tester.instance_variable_set(:@os, "macOS")
        allow(IO).to receive(:popen).and_return(double(pid: 1234))
        allow(Process).to receive(:kill)

        expect(tester.logger).to receive(:record_process_event).with(
          hash_including(
            timestamp: an_instance_of(String),
            username: tester.username,
            process_name: "TextEdit",
            process_command: tester.command,
            process_id: 1234
          )
        )

        tester.send(:execute_process, "TextEdit")
      end

      it "raises error when invalid process" do
        tester.instance_variable_set(:@os, "macOS")

        expect { tester.send(:execute_process, "InvalidProgram") }.to raise_error(SystemExit, /Must provide valid process name./)
      end
    end

    context "Windows" do
      it "successfully records a process event" do
        tester.instance_variable_set(:@os, "Windows")
        allow(IO).to receive(:popen).and_return(double(pid: 1234))
        allow(Process).to receive(:kill)

        expect(tester.logger).to receive(:record_process_event).with(
          hash_including(
            timestamp: an_instance_of(String),
            username: tester.username,
            process_name: "notepad.exe",
            process_command: tester.command,
            process_id: 1234
          )
        )

        tester.send(:execute_process, "notepad.exe")
      end

      it "raises error when invalid process" do
        tester.instance_variable_set(:@os, "Windows")

        expect { tester.send(:execute_process, "InvalidProgram") }.to raise_error(SystemExit, /Must provide valid process name./)
      end
    end

    context "Linux" do
      it "successfully records a process event" do
        tester.instance_variable_set(:@os, "Linux")
        allow(IO).to receive(:popen).and_return(double(pid: 1234))
        allow(Process).to receive(:kill)

        expect(tester.logger).to receive(:record_process_event).with(
          hash_including(
            timestamp: an_instance_of(String),
            username: tester.username,
            process_name: "pwd",
            process_command: tester.command,
            process_id: 1234
          )
        )

        tester.send(:execute_process, "pwd")
      end

      it "raises error when invalid process" do
        tester.instance_variable_set(:@os, "Linux")

        expect { tester.send(:execute_process, "InvalidProgram") }.to raise_error(SystemExit, /Must provide valid process name./)
      end
    end
  end

  describe "#handle_file_actions" do
    let(:test_file) { "test_file.txt" }

    after do
      File.delete(test_file) if File.exist?(test_file)
    end

    it "creates a file" do
      expect(tester.logger).to receive(:record_file_event).with(
        hash_including(
          timestamp: an_instance_of(String),
          username: tester.username,
          process_name: an_instance_of(String),
          process_command: tester.command,
          process_id: an_instance_of(Integer),
          file_path: an_instance_of(String),
          activity: "create"
        )
      )

      tester.send(:handle_file_actions, test_file, "create", "Test content")
      expect(File.exist?(test_file)).to be true
    end

    it "modifies a file" do
      File.write(test_file, "Initial content")

      expect(tester.logger).to receive(:record_file_event).with(
        hash_including(
          timestamp: an_instance_of(String),
          username: tester.username,
          process_name: an_instance_of(String),
          process_command: tester.command,
          process_id: an_instance_of(Integer),
          file_path: an_instance_of(String),
          activity: "modify"
        )
      )

      tester.send(:handle_file_actions, test_file, "modify", "Modified content")
      expect(File.read(test_file)).to include("Modified content")
    end

    it "deletes a file" do
      File.write(test_file, "Content to be deleted")

      expect(tester.logger).to receive(:record_file_event).with(
        hash_including(
          timestamp: an_instance_of(String),
          username: tester.username,
          process_name: an_instance_of(String),
          process_command: tester.command,
          process_id: an_instance_of(Integer),
          file_path: an_instance_of(String),
          activity: "delete"
        )
      )

      tester.send(:handle_file_actions, test_file, "delete")
      expect(File.exist?(test_file)).to be false
    end
  end

  describe "#tcp_connection" do
    it "records a network event for TCP connection" do

      expect(tester.logger).to receive(:record_network_event).with(
        hash_including(
          timestamp: an_instance_of(String),
          username: tester.username,
          process_name: an_instance_of(String),
          process_command: tester.command,
          process_id: an_instance_of(Integer),
          protocol: "TCP",
          data_in_bytes: an_instance_of(Integer),
          destination_addr: "example.com",
          destination_port: 80,
          source_addr: an_instance_of(String),
          source_port: an_instance_of(Integer)
        )
      )

      tester.send(:tcp_connection, "example.com", 80)
    end
  end

  describe "#http_get_request" do
    it "records a network event for GET request" do

      expect(tester.logger).to receive(:record_network_event).with(
        hash_including(
          timestamp: an_instance_of(String),
          username: tester.username,
          process_name: an_instance_of(String),
          process_command: tester.command,
          process_id: an_instance_of(Integer),
          protocol: "HTTP",
          data_in_bytes: 0,
          destination_addr: "example.com",
          destination_port: 80,
          source_addr: an_instance_of(String),
          source_port: an_instance_of(Integer)
        )
      )

      tester.send(:http_get_request, "http://example.com")
    end
  end

  describe "#udp_transmission" do
    it "records a network event for UDP transmission" do

      expect(tester.logger).to receive(:record_network_event).with(
        hash_including(
          timestamp: an_instance_of(String),
          username: tester.username,
          process_name: an_instance_of(String),
          process_command: tester.command,
          process_id: an_instance_of(Integer),
          protocol: "UDP",
          data_in_bytes: an_instance_of(Integer),
          destination_addr: "8.8.8.8",
          destination_port: 53,
          source_addr: an_instance_of(String),
          source_port: an_instance_of(Integer)
        )
      )

      tester.send(:udp_transmission, "Test data")
    end
  end
end