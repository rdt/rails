require 'active_support/core_ext/object/try'

module ActionView
  # = Action View Rendering
  module Rendering
    # Returns the result of a render that's dictated by the options hash. The primary options are:
    #
    # * <tt>:partial</tt> - See ActionView::Partials.
    # * <tt>:update</tt> - Calls update_page with the block given.
    # * <tt>:file</tt> - Renders an explicit template file (this used to be the old default), add :locals to pass in those.
    # * <tt>:inline</tt> - Renders an inline template similar to how it's done in the controller.
    # * <tt>:text</tt> - Renders the text passed in out.
    #
    # If no options hash is passed or :update specified, the default is to render a partial and use the second parameter
    # as the locals hash.
    def render(options = {}, locals = {}, &block)
      case options
      when Hash
        if block_given?
          _render_partial(options.merge(:partial => options[:layout]), &block)
        elsif options.key?(:partial)
          _render_partial(options)
        else
          TemplateRenderer.new(self, options).render
        end
      when :update
        update_page(&block)
      else
        _render_partial(:partial => options, :locals => locals)
      end
    end

    class TemplateRenderer #:nodoc:
      def initialize(view_context, options)
        @view = view_context
        @options = options
      end

      def render
        setup
        instrument do
          render_layout(render_template)
        end
      end

    private

      def setup
        @template = find_template
        @view.lookup_context.freeze_formats(@template.formats, true)

        @layout = nil
        @payload = { :identifier => @template.identifier }
        if @options.key?(:layout)
          @layout = @view.find_layout(@options[:layout])
          @payload[:layout] = @layout.try(:virtual_path)
        end

        @locals = @options[:locals] || {}
      end

      def render_template
        @template.render(@view, @locals) { |*name| @view._layout_for(*name) }
      end

      def render_layout(content)
        if @layout
          @view.instance_variable_get('@_content_for')[:layout] = content
          @view._render_layout(@layout, @locals)
        else
          content
        end
      end

      def instrument(&block)
        ActiveSupport::Notifications.instrument(:'render_template.action_view', @payload, &block)
      end

      def find_template
        if @options.key?(:inline)
          handler = Template.handler_class_for_extension(@options[:type] || "erb")
          Template.new(@options[:inline], "inline template", handler, {})
        elsif @options.key?(:text)
          Template::Text.new(@options[:text], @view.formats.try(:first))
        elsif @options.key?(:file)
          @view.with_fallbacks { @view.find_template(@options[:file], @options[:prefix]) }
        elsif @options.key?(:template)
          @options[:template].respond_to?(:render) ?
            @options[:template] : @view.find_template(@options[:template], @options[:prefix])
        end
      end
    end
  end
end
