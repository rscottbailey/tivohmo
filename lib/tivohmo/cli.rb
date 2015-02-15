require 'clamp'
require 'yaml'
require 'active_support/core_ext/string'
require 'sigdump/setup'
require 'tivohmo'
require 'open-uri'

module TivoHMO

  # The command line interface to tivohmo
  class CLI < Clamp::Command
    include GemLogger::LoggerSupport

    def self.description
      desc = <<-DESC
        TivoHMO version #{TivoHMO::VERSION}

        Runs a HMO server.  Specify one or more applications to show up as top level
        shares in the TiVo Now Playing view.  The application, identifier,
        transcoder, metadata options can be given in groups to apply the transcoder
        and metadata to each application - uses the application's default if not given

        e.g.

        tivohmo -a TivoHMO::Adapters::Filesystem::Application -i ~/Video/Movies \\
                -a TivoHMO::Adapters::Filesystem::Application -i ~/Video/TV

        to run two top level filesystem video serving apps for different dirs, or

        tivohmo -a TivoHMO::Adapters::Filesystem::Application -t Vids -i ~/Video

        to run the single filesystem app with a custom title, or

        tivohmo -a TivoHMO::Adapters::Plex::Application -t PlexVideo -i localhost

        to run the single plex app with a custom title
      DESC
      desc.split("\n").collect(&:strip).join("\n")
    end

    option ["-d", "--debug"],
           :flag, "debug output\n",
           default: false

    option ["-v", "--version"],
           :flag, "print version and exit\n",
           default: false

    option ["-r", "--preload"],
           :flag, "Preloads all lazy container listings\n",
           default: false

    option ["-l", "--logfile"],
           "FILE", "log to given file\n"

    option ["-p", "--port"],
           "PORT", "run server using PORT\n",
           default: 9032 do |s|
      Integer(s)
    end

    option ["-f", "--configuration"],
           "FILE", "load configuration from given filename\n"

    option ["-a", "--application"],
           "CLASSNAME", "use the given application class\n",
           multivalued: true

    option ["-i", "--identifier"],
           "IDENTIFIER", "use the given application identifier\n" +
           "a string that has meaning to the application\n",
           multivalued: true

    option ["-t", "--title"],
           "TITLE", "use the given title for the application\n",
           multivalued: true

    option ["-T", "--transcoder"],
           "CLASSNAME", "override the application's transcoder class\n",
           multivalued: true

    option ["-M", "--metadata"],
           "CLASSNAME", "override the application's metadata class\n",
           multivalued: true

    option ["-b", "--beacon"],
           "LIMIT:INTERVAL", "configure beacon limit and/or interval\n"

    def execute

      if version?
        puts "TivoHMO Version #{TivoHMO::VERSION}"
        return
      end

      setup_logging

      logger.info "TivoHMO #{TivoHMO::VERSION} starting up"

      TivoHMO::Config.instance.setup(configuration || 'tivohmo.yml')

      # allow cli option to override config file
      set_if_default(:port, TivoHMO::Config.instance.get(:port).try(:to_i))

      signal_usage_error "at least one application is required" unless application_list.present?
      signal_usage_error "an initializer is needed for each application" unless
          application_list.size == identifier_list.size

      (application_list + transcoder_list + metadata_list).each do |c|
        if c && c.starts_with?('TivoHMO::Adapters::')
          path = c.downcase.split('::')[0..-2].join('/')
          require path
        end
      end

      server = TivoHMO::API::Server.new

      apps_with_config = application_list.zip(identifier_list,
                                              title_list,
                                              transcoder_list,
                                              metadata_list)

      apps_with_config.each do |app_classname, identifier, title, transcoder, metadata|
        app_class = app_classname.constantize
        app = app_class.new(identifier)

        if title
          app.title = title
        else
          app.title = "#{app.title} on #{server.title}"
        end

        app.transcoder_class = transcoder.constantize if transcoder
        app.metadata_class = metadata.constantize if metadata
        server.add_child(app)
      end

      preload_containers(server) if preload?

      opts = {}
      if beacon.present?
        limit, interval = beacon.split(":")
        opts[:limit] = limit.to_i if limit.present?
        opts[:interval] = interval.to_i if interval.present?
      end
      notifier = TivoHMO::Beacon.new(port, **opts)

      TivoHMO::Server.start(server, port) do |s|
        wait_for_server { notifier.start }
      end
    end

    private

    def setup_logging
      Logging.logger.root.level = :debug if debug?

      if logfile.present?
        appender = Logging.appenders.rolling_file(
            logfile,
            truncate: true,
            age: 'daily',
            keep: 3,
            layout: Logging.layouts.pattern(
                pattern: Logging.appenders.stdout.layout.pattern
            )
        )

        # hack to assign stdout/err to logfile if logging to file
        io = appender.instance_variable_get(:@io)
        $stdout = $stderr = io

        Logging.logger.root.appenders = appender
      end
    end

    def set_if_default(attr, new_value)
      self.send("#{attr}=", new_value) if new_value && self.send(attr) == self.send("default_#{attr}")
    end

    def preload_containers(server)
      Thread.new do
        logger.info "Preloading lazily cached containers"
        queue = server.children.dup
        queue.each do |i|
          logger.debug("Loading children for #{i.title_path}")
          queue.concat(i.children)
        end
        logger.info "Preload complete"
      end
    end

    def wait_for_server
      Thread.new do
        while true
          begin
            open("http://localhost:#{port}/TiVoConnect?Command=QueryServer") {}
            yield
            break
          rescue Exception => e
          end
        end
      end
    end

  end

end
