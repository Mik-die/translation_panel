require 'spec_helper'

describe TranslationPanel do
  it "should be valid" do
    TranslationPanel.should be_a(Module)
  end
end

describe HomeController, :type => :controller do
  render_views
  describe "index" do
    before :all do
      I18n.backend.store.flushdb
    end

    describe "normal processing" do
      it "doesn't call TranslationPanel in filters" do
        TranslationPanel.should_not_receive(:show!)
        TranslationPanel.should_not_receive(:kill!)
        get :index
      end
    end

    describe "processing with TranslationPanel" do
      it "shows links to TranslationPanel assets" do
        get :index, :translator => true
        response.body.should have_selector("link", :href => "/assets/redis_translator.css")
        response.body.should have_selector("script", :src => "/assets/redis_translator.js")
      end
    end

    describe "both processings" do
      before :all do
        I18n.backend.store_translations "ru", :some_i18n_key => "Some Key!"
        I18n.backend.store_translations "ru", :html_part => "<b>Some HTML</b>"
      end

      it "shows existing tanslates" do
        get :index
        response.body.should include("Some Key!")
        response.body.should have_selector("b") do |bold|
          bold.should include("Some HTML")
        end
      end

      it "shows stubs for absent translates" do
        get :index
        response.body.should have_selector("span.translation_missing",
                      :title => "translation missing: ru.long.chain.of.keys")
      end
    end
  end
end

describe Admin::TranslationsController, :type => :controller do
  describe "new" do
    before :all do
      I18n.backend.store.flushdb
    end
    
    it "saves new translation" do
      get :new, :locale => "ru", :key => "some.key", :value => "some_value"
      I18n.t("some.key", :locale => "ru").should == "some_value"
    end
    
    it 'updates existing translation' do
      get :new, :locale => "ru", :key => "some.key", :value => "other_value"
      I18n.t("some.key", :locale => "ru").should == "other_value"
    end
  end
end
