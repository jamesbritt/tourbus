# common.rb - Common settings, requires and helpers
unless defined? TOURBUS_LIB_PATH
  TOURBUS_LIB_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
  $:<< TOURBUS_LIB_PATH unless $:.include? TOURBUS_LIB_PATH
end

require 'rubygems'

gem 'mechanize', ">= 0.8.5"
gem 'trollop', ">= 1.10.0"
gem 'faker', '>= 0.3.1'

# TODO: I'd like to remove dependency on Rails. Need to see what all
# we're using (like classify) and remove each dependency individually.
# require 'activesupport'

# TODO Move to seperate file, maybe, if that feels cleaner



class StolenInflections
  class << self

    def camelize(lower_case_and_underscored_word, first_letter_in_uppercase = true)
      if first_letter_in_uppercase
        lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
      else
        lower_case_and_underscored_word.first.downcase + camelize(lower_case_and_underscored_word)[1..-1]
      end
    end

  end

  # Ruby 1.9 introduces an inherit argument for Module#const_get and
  # #const_defined? and changes their default behavior.
  if Module.method(:const_get).arity == 1
    # Tries to find a constant with the name specified in the argument string:
    #
    #   "Module".constantize     # => Module
    #   "Test::Unit".constantize # => Test::Unit
    #
    # The name is assumed to be the one of a top-level constant, no matter whether
    # it starts with "::" or not. No lexical context is taken into account:
    #
    #   C = 'outside'
    #   module M
    #     C = 'inside'
    #     C               # => 'inside'
    #     "C".constantize # => 'outside', same as ::C
    #   end
    #
    # NameError is raised when the name is not in CamelCase or the constant is
    # unknown.
    def self.constantize(camel_cased_word)
      names = camel_cased_word.split('::')
      names.shift if names.empty? || names.first.empty?

      constant = Object
      names.each do |name|
        constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
      end
      constant
    end
  else
    def self.constantize(camel_cased_word) #:nodoc:
      names = camel_cased_word.split('::')
      names.shift if names.empty? || names.first.empty?

      constant = Object
      names.each do |name|
        constant = constant.const_get(name, false) || constant.const_missing(name)
      end
      constant
    end
  end
end

class String

  # By default, +camelize+ converts strings to UpperCamelCase. If the argument to +camelize+
  # is set to <tt>:lower</tt> then +camelize+ produces lowerCamelCase.
  #a
  # +camelize+ will also convert '/' to '::' which is useful for converting paths to namespaces.
  #
  # Examples:
  #   "active_record".camelize                # => "ActiveRecord"
  #   "active_record".camelize(:lower)        # => "activeRecord"
  #   "active_record/errors".camelize         # => "ActiveRecord::Errors"
  #   "active_record/errors".camelize(:lower) # => "activeRecord::Errors"
  def camelize(first_letter_in_uppercase = true)
    StolenInflections.camelize(self, first_letter_in_uppercase)
  end

  def constantize
    StolenInflections.constantize self
  end

  def classify
    # strip out any leading schema name
    StolenInflections.camelize(self.to_s.sub(/.*\./, '') )
  end

end



class Hash
  # Return a new hash with all keys converted to symbols.
  def symbolize_keys
    inject({}) do |options, (key, value)|
      options[(key.to_sym rescue key) || key] = value
    options
    end
  end

end

require 'monitor'
require 'faker'
require 'tour_bus'
require 'runner'
require 'tour'

class TourBusException < Exception; end

def require_all_files_in_folder(folder, extension = "*.rb")
  for file in Dir[File.join('.', folder, "**/#{extension}")]
    require file
  end
end

