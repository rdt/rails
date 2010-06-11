require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/object/blank'

module ActionController
  def self.add_renderer(key, &block)
    Renderers.add(key, &block)
  end

  module Renderers
    extend ActiveSupport::Concern

    included do
      class_attribute :_renderers
      self._renderers = {}.freeze
    end

    module ClassMethods
      def _write_render_options
        renderers = _renderers.map do |name, value|
          <<-RUBY_EVAL
            when options.key?(:#{name})
              _render_option_#{name}(body, options.delete(:#{name}), options)
          RUBY_EVAL
        end

        class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          def _render_template(body, options)
            case
            #{renderers.join}
            else
              super
            end
          end
        RUBY_EVAL
      end

      def use_renderers(*args)
        new = _renderers.dup
        args.each do |key|
          new[key] = RENDERERS[key]
        end
        self._renderers = new.freeze
        _write_render_options
      end
      alias use_renderer use_renderers
    end

    RENDERERS = {}
    def self.add(key, &block)
      define_method("_render_option_#{key}", &block)
      RENDERERS[key] = block
      All._write_render_options
    end

    module All
      extend ActiveSupport::Concern
      include Renderers

      INCLUDED = []
      included do
        self._renderers = RENDERERS
        _write_render_options
        INCLUDED << self
      end

      def self._write_render_options
        INCLUDED.each(&:_write_render_options)
      end
    end

    add :json do |body, json, options|
      self.content_type ||= Mime::JSON
      json = ActiveSupport::JSON.encode(json, options) unless json.respond_to?(:to_str)
      json = "#{options[:callback]}(#{json})" unless options[:callback].blank?
      body << json
    end

    add :js do |body, js, options|
      self.content_type ||= Mime::JS
      js = js.to_js(options) if js.respond_to?(:to_js)
      body << js
    end

    add :xml do |body, xml, options|
      self.content_type ||= Mime::XML
      xml = xml.to_xml(options) if xml.respond_to?(:to_xml)
      body << xml
    end

    add :update do |body, proc, options|
      self.content_type = Mime::JS
      view_context = self.view_context
      generator = ActionView::Helpers::PrototypeHelper::JavaScriptGenerator.new(view_context, &proc)
      body << generator.to_s
    end
  end
end
