require 'active_support/core_ext/string/inflections'
require 'listen'

module TivoHMO
  module Adapters
    module Plex

      # A Container based on a filesystem folder
      class Section < TivoHMO::API::Container
        include GemLogger::LoggerSupport
        include MonitorMixin

        attr_reader :delegate

        def initialize(delegate)
          # TODO: handle string for section for adding roots from CLI
          @delegate = delegate

          super(delegate.key)

          self.title = delegate.title
          self.content_type = "x-container/tivo-videos"
          self.modified_at = Time.at(delegate.updated_at.to_i)
          self.created_at = Time.at(delegate.updated_at.to_i)
        end

        def children
          synchronize do
            if super.blank?
              Array(delegate.all).each do |media|
                if media.is_a?(::Plex::Movie)
                  add_child(Movie.new(media))
                elsif media.is_a?(::Plex::Show)
                  add_child(Show.new(media))
                else
                  logger.error "Unknown type for #{media} in #{self}"
                end
              end
            end
          end

          super
        end

      end

    end
  end
end