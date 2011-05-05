require 'spec_helper'

def with_max_links(num)
  original = SitemapGenerator::MAX_SITEMAP_LINKS
  SitemapGenerator.const_set(:MAX_SITEMAP_LINKS, num)
  yield
  SitemapGenerator.const_set(:MAX_SITEMAP_LINKS, original)
end

describe "SitemapGenerator" do

  describe "root" do
    it "should be set to the root of the gem" do
      SitemapGenerator.root.should == File.expand_path('../../../' , __FILE__)
    end
  end

  describe "clean task" do
    before :each do
      copy_sitemap_file_to_rails_app
      FileUtils.touch(rails_path('public/sitemap_index.xml.gz'))
      Helpers.invoke_task('sitemap:clean')
    end

    it "should delete the sitemaps" do
      file_should_not_exist(rails_path('public/sitemap_index.xml.gz'))
    end
  end

  describe "fresh install" do
    before :each do
      delete_sitemap_file_from_rails_app
      Helpers.invoke_task('sitemap:install')
    end

    it "should create config/sitemap.rb" do
      file_should_exist(rails_path('config/sitemap.rb'))
    end

    it "should create config/sitemap.rb matching template" do
      sitemap_template = SitemapGenerator.templates.template_path(:sitemap_sample)
      files_should_be_identical(rails_path('config/sitemap.rb'), sitemap_template)
    end
  end

  describe "install multiple times" do
    before :each do
      copy_sitemap_file_to_rails_app
      Helpers.invoke_task('sitemap:install')
    end

    it "should not overwrite config/sitemap.rb" do
      sitemap_file = File.join(SitemapGenerator.root, 'spec/sitemap.file')
      files_should_be_identical(sitemap_file, rails_path('config/sitemap.rb'))
    end
  end

  describe "generate sitemap" do
    before :each do
      with_max_links(10) {
        Helpers.invoke_task('sitemap:refresh:no_ping')
      }
    end

    it "should create sitemaps" do
      file_should_exist(rails_path('public/sitemap_index.xml.gz'))
      file_should_exist(rails_path('public/sitemap1.xml.gz'))
      file_should_exist(rails_path('public/sitemap2.xml.gz'))
      file_should_not_exist(rails_path('public/sitemap3.xml.gz'))
    end

    it "should have 14 links" do
      SitemapGenerator::Sitemap.link_count.should == 14
    end

    it "index XML should validate" do
      gzipped_xml_file_should_validate_against_schema rails_path('public/sitemap_index.xml.gz'), 'siteindex'
    end

    it "sitemap XML should validate" do
      gzipped_xml_file_should_validate_against_schema rails_path('public/sitemap1.xml.gz'), 'sitemap'
      gzipped_xml_file_should_validate_against_schema rails_path('public/sitemap2.xml.gz'), 'sitemap'
    end

    it "index XML should not have excess whitespace" do
      gzipped_xml_file_should_have_minimal_whitespace rails_path('public/sitemap_index.xml.gz')
    end

    it "sitemap XML should not have excess whitespace" do
      gzipped_xml_file_should_have_minimal_whitespace rails_path('public/sitemap1.xml.gz')
    end
  end

  describe "sitemap path" do
    before :each do
      ::SitemapGenerator::Sitemap.default_host = 'http://test.local'
      ::SitemapGenerator::Sitemap.filename = 'sitemap'
      FileUtils.rm_rf(rails_path('public/sitemaps'))
    end

    it "should allow changing of the filename" do
      sm = ::SitemapGenerator::Sitemap
      sm.filename = 'geo_sitemap'
      sm.create do
        add '/goerss', :geo => { :format => 'georss' }
        add '/kml', :geo => { :format => 'kml' }
      end

      file_should_exist(rails_path('public/geo_sitemap_index.xml.gz'))
      file_should_exist(rails_path('public/geo_sitemap1.xml.gz'))
    end

    it "should support setting a sitemap path" do
      directory_should_not_exist(rails_path('public/sitemaps/'))

      sm = ::SitemapGenerator::Sitemap
      sm.sitemaps_path = 'sitemaps/'
      sm.create do
        add '/'
        add '/another'
      end

      file_should_exist(rails_path('public/sitemaps/sitemap_index.xml.gz'))
      file_should_exist(rails_path('public/sitemaps/sitemap1.xml.gz'))
    end

    it "should support setting a deeply nested sitemap path" do
      directory_should_not_exist(rails_path('public/sitemaps/deep/directory'))

      sm = ::SitemapGenerator::Sitemap
      sm.sitemaps_path = 'sitemaps/deep/directory/'
      sm.create do
        add '/'
        add '/another'
        add '/yet-another'
      end

      file_should_exist(rails_path('public/sitemaps/deep/directory/sitemap_index.xml.gz'))
      file_should_exist(rails_path('public/sitemaps/deep/directory/sitemap1.xml.gz'))
    end
  end

  describe "external dependencies" do
    describe "rails" do
      before :each do
        @rails = Rails
        Object.send(:remove_const, :Rails)
      end

      after :each do
        Object::Rails = @rails
      end

      it "should work outside of Rails" do
        defined?(Rails).should be_nil
        lambda { ::SitemapGenerator::LinkSet.new }.should_not raise_exception
      end
    end
  end

  protected

  #
  # Helpers
  #

  def rails_path(file)
    SitemapGenerator.app.root + file
  end

  def copy_sitemap_file_to_rails_app
    FileUtils.cp(File.join(SitemapGenerator.root, 'spec/sitemap.file'), SitemapGenerator.app.root + 'config/sitemap.rb')
  end

  def delete_sitemap_file_from_rails_app
    FileUtils.remove(SitemapGenerator.app.root + 'config/sitemap.rb')
  rescue
    nil
  end
end
