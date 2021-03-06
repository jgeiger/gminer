require 'spec_helper'

describe SeriesItemsController do

  describe "handling GET /series_items" do
    before(:each) do
      series_item = Factory.build(:series_item)
      @series_items = [series_item]
      @series_items.stub!(:total_pages).and_return(1)
      SeriesItem.stub!(:page).and_return(@series_items)
    end

    def do_get
      get :index
    end

    it "should be successful" do
      do_get
      response.should be_success
    end

    it "should render index template" do
      do_get
      response.should render_template('index')
    end

    it "should assign the found annotations for the view" do
      do_get
      assigns[:series_items].should == @series_items
    end

  end

  describe "GET show" do
    it "assigns the requested series_item as @series_item" do
      user = Factory.build(:user, :id => "1")
      controller.should_receive(:admin?).and_return(true)
      controller.should_receive(:current_user).and_return(user)

      series_item = Factory.build(:series_item)
      SeriesItem.stub!(:first).with(:conditions => {:geo_accession => "GDS1234"}).and_return(series_item)
      series_item.should_receive(:prev_next).and_return(["GDS1", "GDS3"])
      series_item.should_receive(:count_by_ontology_array).and_return({})
      get :show, :id => "GDS1234"
      assigns[:series_item].should equal(series_item)
    end

    it "redirects for an invalid series_item" do
      SeriesItem.stub!(:first).with(:conditions => {:geo_accession => "GDS1234"}).and_raise(ActiveRecord::RecordNotFound)
      get :show, :id => "GDS1234"
      response.should redirect_to(series_items_url)
    end
  end
end
