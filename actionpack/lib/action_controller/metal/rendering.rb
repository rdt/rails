module ActionController
  module Rendering
    extend ActiveSupport::Concern

    include ActionController::RackDelegation
    include AbstractController::Rendering

    # Before processing, set the request formats in current controller formats.
    def process_action(*) #:nodoc:
      self.formats = request.formats.map { |x| x.to_sym }
      super
    end

    # Check for double render errors and set the content_type after rendering.
    def render(*args, &block) #:nodoc:
      raise ::AbstractController::DoubleRenderError if response_body

      super(*args, &block).tap do
        self.content_type ||= Mime[formats.first].to_s
      end
    end

    private

      # Normalize arguments by catching blocks and setting them on :update.
      def _normalize_args(*args, &block) #:nodoc:
        super.tap do |opts|
          opts[:update] = block if block_given?
        end
      end

      # Normalize both text and status options.
      def _normalize_options(options) #:nodoc:
        if options.key?(:text) && options[:text].respond_to?(:to_text)
          options[:text] = options[:text].to_text
        end

        if options[:status]
          options[:status] = Rack::Utils.status_code(options[:status])
        end

        super
      end

      # Process controller specific options, as status, content-type and location.
      def _process_options(options) #:nodoc:
        status, content_type, location = options.values_at(:status, :content_type, :location)

        self.status = status if status
        self.content_type = content_type if content_type
        self.headers["Location"] = url_for(location) if location

        super
      end

  end
end
