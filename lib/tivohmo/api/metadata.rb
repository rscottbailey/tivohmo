module TivoHMO
  module API

    # Metadata abstraction for containing and displaying supplemental info about an Item
    module Metadata
      extend ActiveSupport::Concern
      include GemLogger::LoggerSupport

      attr_accessor :item,

                    :title,
                    :description,

                    :time,
                    :start_time,
                    :stop_time,

                    :actual_showing,
                    :bookmark,
                    :recording_quality, # hash of :name, :value
                    :duration,

                    :showing_bits,
                    :part_count,
                    :part_index,

                    :actors,
                    :choreographers,
                    :directors,
                    :producers,
                    :executive_producers,
                    :writers,
                    :hosts,
                    :guest_stars,
                    :program_genres,

                    :original_air_date,
                    :movie_year,
                    :advisory,
                    :color_code, # hash of :name, :value
                    :show_type, # hash of :name, :value
                    :program_id,
                    :mpaa_rating, # hash of :name, :value
                    :star_rating, # hash of :name, :value
                    :tv_rating, # hash of :name, :value

                    :is_episode,
                    :episode_number,
                    :episode_title,

                    :series_genres,
                    :series_title,
                    :series_id,

                    :channel # hash of :major_number, :minor_number, :callsign


      def initialize(item)
        self.item = item
        self.showing_bits = 4096
        self.is_episode = true
        self.recording_quality = {name: "HIGH", value: "75"}
        self.color_code = {name: 'COLOR', value: '4'}
        self.show_type = {name: 'SERIES', value: '5'}
        self.channel = {major_number: '0', minor_number: '0', callsign: ''}
      end

      def time
        @time ||= Time.now
      end

      def start_time
        @start_time ||= time
      end

      def stop_time
        @stop_time ||= time + duration
      end

    end

  end
end
