module ActionView
  module Template::Handlers
    class RJS < Template::Handler
      include Compilable

      self.default_format = Mime::JS

      def compile(template)
        "update_page { |page| #{template.source}\n}"
      end

      def default_format
        Mime::JS
      end
    end
  end
end
