#############
# EventLogger
#
# This class provides logging functionality for the Agent Regression Tester (ART).
# It records and persists events generated during the testing process including
# process executions, file operations, and network activities. Predefined sets of
# required attributes are used to ensure data integrity and completeness for each
# type of logged event.
#
# Usage:
#   logger = EventLogger.new
#   logger.record_process_event(...)
#   logger.record_file_event(...)
#   logger.record_network_event(...)
#   logger.persist_logs
#

require "json"
require "logger"

BASE_REQUIRED_LOG_ATTRS = %i[timestamp username process_name process_command process_id]
FILE_REQUIRED_ATTRS = BASE_REQUIRED_LOG_ATTRS + %i[file_path activity]
NETWORK_REQUIRED_ATTRS = BASE_REQUIRED_LOG_ATTRS + %i[
  protocol
  data_in_bytes
  destination_addr
  destination_port
  source_addr
  source_port
]

class EventLogger
  def initialize(json_log_file: "logs/art_log.json", text_log_file: "logs/art_log.log")
    @json_log_file = json_log_file
    @events = []
    @logger = configure_text_logger(text_log_file)
  end

  def record_process_event(**attrs)
    validate_log_attributes(BASE_REQUIRED_LOG_ATTRS, attrs)

    @events << attrs
    @logger.info(attrs)
  end

  def record_file_event(**attrs)
    validate_log_attributes(FILE_REQUIRED_ATTRS, attrs)

    @events << attrs
    @logger.info(attrs)
  end

  def record_network_event(**attrs)
    validate_log_attributes(NETWORK_REQUIRED_ATTRS, attrs)

    @events << attrs
    @logger.info(attrs)
  end

  def record_logging_error(error)
    @events << { error: }
    @logger.error(error)

    abort(error)
  end

  def persist_logs
    File.write(@json_log_file, JSON.pretty_generate(@events))
    @logger.info("Persisted #{@events.length} events to #{@json_log_file}")
  end

  private

  def validate_log_attributes(required_attrs, input_attrs)
    missing_keys = required_attrs - input_attrs.keys
    empty_values = required_attrs.select { |key| input_attrs[key].nil? || input_attrs[key].to_s.empty? }

    if missing_keys.any? || empty_values.any?
      record_logging_error(
        "Ensure you have provided all attributes and values for each of the following: #{required_attrs}"
      )
    end
  end

  def configure_text_logger(log_file)
    # logger = Logger.new(log_file) => If we want to persist ALL logs
    logger = Logger.new(File.open(log_file, "w"))
    logger.level = Logger::INFO
    logger.formatter = proc do |severity, datetime, program_name, msg|
      "[#{datetime}] #{severity}: #{msg}\n"
    end
    logger
  end
end