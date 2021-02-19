# frozen_string_literal: true

require 'openhab/log/configuration'
require 'java'
require 'pp'

module OpenHAB
  #
  # Provides access to the OpenHAB logging using a Ruby logging methods
  #
  module Log
    #
    # Ruby Logger that forwards messages at appropriate levels to OpenHAB Logger
    #
    class Logger
      java_import org.slf4j.LoggerFactory

      # @return [Array] Supported logging levels
      LEVELS = %i[trace debug warn info error].freeze
      private_constant :LEVELS

      #
      # Regex for matching internal calls in a stack trace
      #
      INTERNAL_CALL_REGEX = %r{(openhab-scripting-.*/lib)|(org/jruby/)}.freeze
      private_constant :INTERNAL_CALL_REGEX

      #
      # Create a new logger
      #
      # @param [String] name of the logger
      #
      def initialize(name)
        @sl4fj_logger = LoggerFactory.getLogger(name)
      end

      # Dynamically define the methods for each level as identified by the levels constant
      # This creates a method for each level that looks like this
      # def <level>(msg=nil, &block)
      #   log(severity: <level>, msg: msg, &block)
      # end
      #
      # Also creates methods to check if the different logging levels are enabled
      #
      LEVELS.each do |level|
        define_method(level) do |msg = nil, &block|
          log(severity: level, msg: msg, &block)
        end
        define_method("#{level}_enabled?") { @sl4fj_logger.send("is_#{level}_enabled") }
      end

      #
      # Cleans the backtrace of an error to remove internal calls. If logging is set
      # to debug or lower, the full backtrace is kept
      #
      # @param [Exception] error An exception to be cleaned
      #
      # @return [Exception] the exception, potentially with a cleaned backtrace.
      #
      def clean_backtrace(error)
        return error if debug_enabled?

        backtrace = error.backtrace_locations.reject { |line| INTERNAL_CALL_REGEX.match? line.to_s }
        error.set_backtrace(backtrace.map(&:to_s))
        error
      end

      private

      #
      # Log a message to the OpenHAB Logger
      #
      # @param [Symbol] severity Severity to log message at
      # @param [Object] msg to log, if no msg supplied and a block is provided,
      #   the msg is taken from the result of the block
      #
      def log(severity:, msg: nil)
        severity = severity.to_sym

        raise ArgumentError, "Unknown Severity #{severity}" unless LEVELS.include? severity

        # Dynamically check enablement of underlying logger, this expands to "is_<level>_enabled"
        return unless send("#{severity}_enabled?")

        # Process block if no message provided
        msg = yield if msg.nil? && block_given?

        msg = message_to_string(msg: msg)

        # Dynamically invoke underlying logger, this expands to "<level>(message)"
        @sl4fj_logger.send(severity, msg)
      end

      #
      # Conver the supplied message object to a String
      #
      # @param [object] msg object to convert
      #
      # @return [String] Msg object as a string
      #
      def message_to_string(msg:)
        case msg
        when ::String
          msg
        when ::Exception
          "#{msg.message} (#{msg.class})\n#{msg.backtrace&.join("\n")}"
        else
          msg.inspect
        end
      end
    end

    @loggers = {}

    # Return a logger with the configured log prefix plus the calling scripts name

    #
    # Create a logger for the current class
    #
    # @return [Logger] for the current class
    #
    def logger
      Log.logger(self.class.name)
    end

    class << self
      #
      # Injects a logger into the base class
      #
      # @param [String] name of the logger
      #
      # @return [Logger] for the supplied name
      #
      def logger(name)
        name ||= self.class.name
        @loggers[name] ||= Log.logger_for(name)
      end

      #
      # Configure a logger for the supplied class name
      #
      # @param [String] classname to configure logger for
      #
      # @return [Logger] for the supplied classname
      #
      def logger_for(classname)
        configure_logger_for(classname)
      end

      private

      #
      # Configure a logger for the supplied classname
      #
      # @param [String] classname to create logger for
      #
      # @return [Logger] Logger for the supplied classname
      #
      def configure_logger_for(classname)
        log_prefix = Configuration.log_prefix
        log_prefix += if classname
                        ".#{classname}"
                      else
                        ".#{log_caller}"
                      end
        Logger.new(log_prefix)
      end

      #
      # Figure out the log prefix
      #
      # @return [String] Prefix for log messages
      #
      def log_caller
        caller_locations.map(&:path)
                        .grep_v(%r{openhab/core/})
                        .grep_v(/rubygems/)
                        .grep_v(%r{lib/ruby})
                        .first
                        .yield_self { |caller| File.basename(caller, '.*') }
      end
    end

    #
    # Add logger method to the object that includes this module
    #
    # @param [Object] base Object to add method to
    #
    #
    def self.included(base)
      class << base
        def logger
          Log.logger(self.class.name)
        end
      end
    end
  end
end
