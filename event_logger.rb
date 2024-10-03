require "json"
require "logger"
require "time"

class EventLogger
  def initialize(json_log_file: "logs/art_log.json", text_log_file: "logs/art_log.log")
    @json_log_file = json_log_file
    @events = []
    @logger = configure_text_logger(text_log_file)
  end

  def record_event(event_type, **details)
    log_data = {
      timestamp: Time.now.iso8601,
      event_type: event_type,
      username: Etc.getlogin,
      hostname: Socket.gethostname,
      **details
    }

    @events << log_data
    @logger.info(log_data)
  end

  def persist_logs
    File.write(@json_log_file, JSON.pretty_generate(@events))
    @logger.info("Persisted #{@events.length} events to #{@json_log_file}")
  end

  private

  def configure_text_logger(log_file)
    # logger = Logger.new(log_file) => If we want to persist ALL logs
    logger = Logger.new(File.open(log_file, 'w'))
    logger.level = Logger::INFO
    logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime}] #{severity}: #{msg}\n"
    end
    logger
  end
end