require "json"
require "logger"
require "time"

class TelemetryLogger
  # def initialize(json_log_file: "logs/art_#{Time.now.iso8601}.json", text_log_file: "logs/art_#{Time.now.iso8601}.log")
  def initialize(json_log_file: "logs/art_log.json", text_log_file: "logs/art_log.log")
    @json_log_file = json_log_file
    @events = []
    @logger = configure_text_logger(text_log_file)
  end

  def record_event(event_type, **details)
    event = build_event(event_type, details)
    @events << event
    @logger.info("Recorded #{event_type}: #{details.inspect}")
    event
  end

  def persist_logs
    File.write(@json_log_file, JSON.pretty_generate(@events))
    @logger.info("Persisted #{@events.length} events to #{@json_log_file}")
  end

  def get_events_by_type(type)
    @events.select { |event| event[:event_type] == type }
  end

  def clear_logs
    @events.clear
    @logger.info("Cleared all logged events")
  end

  private

  def configure_text_logger(log_file)
    logger = Logger.new(log_file)
    logger.level = Logger::INFO
    logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime}] #{severity}: #{msg}\n"
    end
    logger
  end

  def build_event(event_type, details)
    {
      timestamp: Time.now.iso8601,
      event_type: event_type,
      user_context: Etc.getlogin,
      hostname: Socket.gethostname,
      **details
    }
  end
end