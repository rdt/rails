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
    def render(options = {}, locals = {}, &layout_block)
      _body_to_string(render_to_body([], options, locals, &layout_block))
    end

    def render_to_body(body, options = {}, locals = {}, &layout_block)
      case options
      when Hash
        if block_given?
          _render_partial(body, options.merge(:partial => options[:layout]), &layout_block)
        elsif options.key?(:partial)
          _render_partial(body, options)
        else
          _render_template(body, options)
        end
      when :update
        body << update_page(&layout_block)
      else
        _render_partial(body, :partial => options, :locals => locals)
      end

      body
    end

    def _body_to_string(body)
      str = nil
      body.each { |part| str ? str << part.to_s : str = part.to_s } if body
      str
    end

  private

    def _render_template(body, options) #:nodoc:
      TemplateRenderer.new(self, options).render(body)
    end

    class TemplateRenderer #:nodoc:
      def initialize(view_context, options)
        @view, @options = view_context, options
      end

      def render(body)
        setup
        instrument do
          if @layout
            render_layout(body)
          else
            render_template_to_body(body)
          end
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

      def render_layout(body)
        content_for = @view.instance_variable_get('@_content_for')
        content_for[:layout] = render_template_to_string
        @view._render_layout(body, @layout, @locals)
        content_for.delete(:layout)
        body
      end

      def render_template_to_body(body)
        @template.render_to_body(body, @view, @locals) { |*name| @view._layout_for(*name) }
      end

      def render_template_to_string
        @template.render(@view, @locals) { |*name| @view._layout_for(*name) }
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
