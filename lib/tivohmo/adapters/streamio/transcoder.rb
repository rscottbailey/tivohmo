module TivoHMO
  module Adapters
    module StreamIO

      # Transcodes video to tivo format using the streamio gem (ffmpeg)
      class Transcoder < TivoHMO::API::Transcoder
        include GemLogger::LoggerSupport

        # TODO: add ability to pass through data (copy codec)
        # for files that are already (partially?) in the right
        # format for tivo.  Check against a mapping of
        # tivo serial->allowed_formats
        # https://code.google.com/p/streambaby/wiki/video_compatibility

        def transcode(writeable_io)
          tmpfile = Tempfile.new('tivohmo_transcode')
          begin
            transcode_thread = run_transcode(tmpfile.path)

            # give the transcode thread a chance to start up before we
            # start copying from it.  Not strictly necessary, but makes
            # the log messages show up in the right order
            sleep 0.1

            run_copy(tmpfile.path, writeable_io, transcode_thread)
          ensure
            # tmpfile.close
            # tmpfile.unlink
          end

          nil
        end

        private

        def run_transcode(output_filename)
          movie = FFMPEG::Movie.new(item.identifier)
          movie.width
          movie.height
          movie.frame_rate
          movie.video_stream
          movie.video_codec
          movie.video_bitrate
          movie.audio_stream
          movie.audio_codec
          movie.audio_bitrate
          movie.audio_sample_rate
          movie.container

          opts = {
              frame_rate: 29.97,
              resolution: "1920x1080",

              video_codec: "mpeg2video",
              video_bitrate: 16384,
              video_max_bitrate: 30000,
              buffer_size: 4096,

              audio_codec: "ac3",
              audio_bitrate: 448,
              audio_sample_rate: 48000,

              custom: "-f vob"
              # video_min_bitrate: 600,
              # video_bitrate_tolerance: 100,
              # aspect: 1.333333,
              # keyframe_interval: 90,
              # x264_vprofile: "high",
              # x264_preset: "slow",
              # audio_channels: 1,
              # threads: 2,
          }

          t_opts = {
              preserve_aspect_ratio: :width
          }

          transcode_thread = Thread.new do
            begin
              logger.info "Starting transcode to: #{output_filename}"
              transcoded_movie = movie.transcode(output_filename, opts, t_opts) do |progress|
                logger.info "Trancoding #{item}: #{progress}"
                raise "Halted" if Thread.current[:halt]
              end
              logger.info "Transcoding completed, transcoded file size: #{File.size(output_filename)}"
            rescue => e
              logger.error ("Transcode failed: #{e}")
            end
          end

          return transcode_thread
        end

        # we could avoid this if streamio-ffmpeg had a way to output to an IO, but
        # it only supports file based output for now, so have to manually copy the
        # file's bytes to our output stream
        def run_copy(transcoded_filename, writeable_io, transcode_thread)
          logger.info "Starting stream copy from: #{transcoded_filename}"
          file = File.open(transcoded_filename, 'rb')
          begin
            bytes_copied = 0

            # copying the IO from transcoded file to web output
            # stream is faster than the transcoding, and thus we
            # hit eof before transcode is done.  Therefore we need
            # to keep retrying while the transcode thread is alive,
            # then to avoid a race condition at the end, we keep
            # going till we've copied all the bytes
            while transcode_thread.alive? || bytes_copied < File.size(transcoded_filename)
              # sleep a bit at start of thread so we don't have a
              # wasteful tight loop when transcoding is really slow
              sleep 0.2

              while data = file.read(4096)
                writeable_io << data
                bytes_copied += data.size
              end
            end

            logger.info "Stream copy completed, #{bytes_copied} bytes copied"
          rescue => e
            logger.error ("Stream copy failed: #{e}")
            transcode_thread[:halt] = true
          ensure
            file.close
          end
        end

      end

    end
  end
end
