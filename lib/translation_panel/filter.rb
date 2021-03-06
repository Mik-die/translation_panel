module TranslationPanel
  class Filter
    include ActionView::Helpers::TagHelper

    def initialize
      @save_url = '/translations/translations/new'
      @condition = :translation_panel?
    end

    def before(controller)
      if controller.send(@condition)
        TranslationPanel.show!
        if highlight = controller.params[:enable_translation_highlight]
          controller.session[:translation_highlight] = highlight == '1'
        end
      end
      true
    end

    def after(controller)
      if controller.send(@condition) && controller.response.status == 200
        case controller.response.content_type
        when "text/html"
          return unless page = controller.response.body
          return unless page.index("</head>")
          header_part = tag :link, :href => "/assets/translation_panel.css",
                            :media => "screen", :rel => "stylesheet", :type => "text/css"
          header_part+= content_tag :script, "", :src => "/assets/translation_panel.js",
                            :type => "text/javascript"
          page.insert page.index("</head>"), header_part
          panel_params = {:translates => TranslationPanel.values, :action => @save_url, :locale => I18n.locale,
                          :highlight => controller.session[:translation_highlight]}
          body_part = content_tag :script, "translationPanel = #{panel_params.to_json}", {:type => "text/javascript"}, false
          page+= body_part
          controller.response.body = page
        when "text/javascript"
          return unless controller.response.body
          body_part = ";$.translator.addTranslates(#{TranslationPanel.values.to_json});"
          controller.response.body+= body_part
        end
        TranslationPanel.kill!
      end
      true
    end
  end
end
