require 'forwardable'
require 'monitor'
require 'common'

# Assume rubygems is loaded ...
#begin
# gem 'webrat', '=0.4.3'

#rescue Exception
# But if not, don't force it; just move on
require 'webrat'
#end
#require "webrat/core/session"

require 'webrat/mechanize'
require 'test/unit/assertions'

class TourError < StandardError ; end


# A tour is essentially a test suite file. A Tour subclass
# encapsulates a set of tests that can be done, and may contain helper
# and support methods for a given task. If you have a two or three
# paths through a specific area of your website, define a tour for
# that area and create test_ methods for each type of test to be done.

class Tour
  extend Forwardable
  include Webrat::Matchers
  include Webrat::SaveAndOpenPage
  include Test::Unit::Assertions

  attr_reader :host, :tours, :number, :tour_type, :tour_id, :webrat_session

  # delegate goodness to webrat
  [
    :fill_in, 
    :fills_in, 
    :set_hidden_field, 
    :submit_form, 
    :check, 
    :checks, 
    :uncheck, 
    :unchecks, 
    :choose, 
    :chooses, 
    :current_page,
    :select, 
    :selects, 
    :select_datetime, 
    :selects_datetime, 
    :select_date, 
    :selects_date, 
    :select_time, 
    :selects_time, 
    :attach_file, 
    :attaches_file, 
    :click_area, 
    :clicks_area, 
    :click_link, 
    :clicks_link, 
    :click_button, 
    :clicks_button, 
    :field_labeled, 
    :field_by_xpath, 
    :field_with_id, 
    :select_option, 
    :automate, 
    :basic_auth, 
    :check_for_infinite_redirects, 
    :click_link_within, 
    :dom, 
    :header, 
    :http_accept, 
    :infinite_redirect_limit_exceeded?, 
    :internal_redirect?, 
    :redirected_to, 
    :reload, 
    :response_body,
    :simulate, 
    :visit, 
    :within, 
    :xml_content_type?].each {|m| def_delegators(:webrat_session, m) }

    def initialize(host, tours, number, tour_id)
      @host, @tours, @number, @tour_id = host, tours, number, tour_id
      @tour_type = self.send(:class).to_s
      @webrat_session = Webrat::MechanizeAdapter.new
      @webrat_session = Webrat::Session.new(Webrat::MechanizeAdapter.new)
      warn "I am #{self.class}"
      self.visit @host if @host
    end

    # before_tour runs once per tour, before any tests get run
    def before_tour; end

    # after_tour runs once per tour, after all the tests have run
    def after_tour; end

    def setup
    end

    def teardown
    end

    def wait(time)
      sleep time.to_i
    end

    # Lists tours in tours folder. If a string is given, filters the
    # list by that string. If an array of filter strings is given,
    # returns items that match ANY filter string in the array.
    def self.tours(filter=[])
      filter = [filter].flatten
      # All files in tours folder, stripped to basename, that match any item in filter
      # I do loves me a long chain. This returns an array containing
      # 1. All *.rb files in tour folder (recursive)
      # 2. Each filename stripped to its basename
      # 3. If you passed in any filters, these basenames are rejected unless they match at least one filter
      # 4. The filenames remaining are then checked to see if they define a class of the same name that inherits from Tour
      Dir[File.join('.', 'tours', '**', '*.rb')].map {|fn| File.basename(fn, ".rb")}.select {|fn| filter.size.zero? || filter.any?{|f| fn =~ /#{f}/}}.select {|tour| Tour.tour? tour }
    end 

    def self.tests(tour_name)
      Tour.make_tour(tour_name).tests
    end

    def self.tour?(tour_name)
      Object.const_defined?(tour_name.classify) && tour_name.classify.constantize.ancestors.include?(Tour)
    end

    # Factory method, creates the named child class instance
    def self.make_tour(tour_name,host="http://localhost:3000",tours=[],number=1,tour_id=nil)
      tour_name.classify.constantize.new(host,tours,number,tour_id)
    end

    # Returns list of tests in this tour. (Meant to be run on a subclass
    # instance; returns the list of tests available).
    def tests
      methods.grep(/^test_/).map {|m| m.sub(/^test_/,'')}
    end

    def run_test(test_name)
      @test = "test_#{test_name}"
      raise TourBusException.new("run_test couldn't run test '#{test_name}' because this tour did not respond to :#{@test}") unless respond_to? @test
      setup
      send @test
      teardown
    end

    protected

    def session
      @session ||= Webrat::MechanizeSession.new # ? Webrat::MechanizeAdapter.new ?
    end

    def log(message)
      puts "#{Time.now.strftime('%F %H:%M:%S')} Tour ##{@tour_id}: (#{@test}) #{message}"
    end

    # FIXME:  There have been some changes that break older tours; dropping WebCycle and using Webrat
    # These methods either implement the mssing code, or wrap current working methods

    # given "portal", opens "http://#{@host}/portal". Leading slash is
    # optional. "/portal" and "portal" are the same.
    def open_site_page(path)
      warn "WARNING: open_site_page may be deprecated."
      path = path.sub %r{^/}, ""
      open_page "http://#{@host}/#{path}"
    end

    def dump_form
      warn "WARNING: dump_form may be deprecated."
      log "Dumping Forms:"
      page.forms.each do |form|
        puts "Form: #{form.name}"
        puts '-' * 20
        (form.fields + form.radiobuttons + form.checkboxes + form.file_uploads).each do |field|
          puts "  #{field.name}"
        end
      end
    end

    # True if uri ends with the string given. If a regex is given, it is
    # matched instead.
    # 
    # TODO: Refactor me--these were separated out back when Websickle
    # was a shared submodule and we couldn't pollute it. Now that it's
    # frozen these probably belong there.
    def assert_page_uri_matches(uri)
      warn "WARNING: assert_page_uri_matches is deprecated."
      case uri
      when String:
        raise TourError, "Expected page uri to match String '#{uri}' but did not. It was #{page.uri}" unless page.uri.to_s[-uri.size..-1] == uri
      when Regexp:
        raise TourError, "Expected page uri to match Regexp '#{uri}' but did not. It was #{page.uri}" unless page.uri.to_s =~ uri
      end
      log "Page URI ok (#{page.uri} matches: #{uri})"
    end

    # True if page contains (or matches) the given string (or regexp)
    # 
    # TODO: Refactor me--these were separated out back when Websickle
    # was a shared submodule and we couldn't pollute it. Now that it's
    # frozen these probably belong there.
    def assert_page_body_contains(pattern)
      warn "WARNING: assert_page_body_contains is deprecated."
      assert_contain pattern
      log "Page body ok (matches #{pattern})"
    end



    # True if page does not contain (or match) the given string (or regexp)
    # 
    # TODO: Refactor me--these were separated out back when Websickle
    # was a shared submodule and we couldn't pollute it. Now that it's
    # frozen these probably belong there.
    def assert_page_body_does_not_contain(pattern)
      warn "WARNING: assert_page_body_does_not_contain is deprecated."
      assert_not_contain pattern
      log "Page body ok (does not match #{pattern})"
    end
end

