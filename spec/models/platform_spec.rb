require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Platform do

  describe "persist" do
    it "should set the fields and save to the database" do
      p = Factory.build(:platform)
      p.stub!(:platform_hash).and_return({"organism" => "rat", "title" => "title"})
      p.should_receive(:title=).with("title").and_return(true)
      p.should_receive(:organism=).with("rat").and_return(true)
      p.should_receive(:download).and_return(true)
      p.should_receive(:save!).and_return(true)
      p.persist
    end
  end

  describe "platform hash" do
    it "should return the hash for the platform by parsing the file" do
      p = Factory.build(:platform)
      p.should_receive(:fields).and_return(["fields"])
      p.should_receive(:platform_filename).and_return("file.soft")
      p.should_receive(:file_hash).with(["fields"], "file.soft").and_return(true)
      p.platform_hash
    end
  end

  describe "fields" do
    it "should return an array of hashes with field information" do
      p = Factory.build(:platform)
      p.fields.should == [{:value=>"Platform Title", :regex=>/^!Platform_title = (.+?)$/, :name=>"title"}, {:value=>"rat", :regex=>/^!Platform_organism = (.+?)$/, :name=>"organism"}, {:value=>"", :regex=>/^!Platform_series_id = (GSE\d+)/, :name=>"series_ids"}]
    end
  end

  describe "download" do
    it "should download the file if it doesn't exist" do
      p = Factory.build(:platform)
      File.should_receive(:exists?).with(/datafiles\/GPL1355\/GPL1355.soft$/).and_return(false)
      p.should_receive(:download_file).and_return(true)
      p.download
    end
  end

  describe "create series" do
    it "should create the series, save it and create the samples if it exists" do
      p = Factory.build(:platform)
      s = mock(SeriesItem)
      s.should_receive(:persist).and_return(true)
      s.should_receive(:create_samples).and_return(true)
      SeriesItem.should_receive(:first).with(:geo_accession => "1").and_return(s)
      p.create_series(["1"])
    end

    it "should create the series, save it and create the samples if it doesn't exist" do
      p = Factory.build(:platform)
      s = mock(SeriesItem)
      s.should_receive(:persist).and_return(true)
      s.should_receive(:create_samples).and_return(true)
      SeriesItem.should_receive(:first).with(:geo_accession => "1").and_return(nil)
      SeriesItem.should_receive(:new).with({:geo_accession=>"1", :platform_geo_accession=>"GPL1355"}).and_return(s)
      p.create_series(["1"])
    end
  end

  describe "download series files" do
    it "should create the series and download the files from geo" do
      p = Factory.build(:platform)
      p.should_receive(:download).and_return(true)
      p.should_receive(:platform_hash).and_return({"series_ids" => [1]})
      s = mock(SeriesItem)
      s.should_receive(:download).and_return(true)
      SeriesItem.should_receive(:new).with({:geo_accession=>1, :platform_geo_accession=>"GPL1355"}).and_return(s)
      p.download_series_files
    end
  end

  describe "download file" do
    it "should download the file from geo" do
      p = Factory.build(:platform)
      p.should_receive(:make_directory).with(/datafiles\/GPL1355$/).and_return(true)
      p.should_receive(:write_file).with(/datafiles\/GPL1355\/GPL1355.soft$/, "data").and_return(true)
      Platform.should_receive(:get).with("/geo/query/acc.cgi", {:format=>:plain, :query=>{"acc"=>"GPL1355", "targ"=>"self", "form"=>"text", "view"=>"brief"}}).and_return("data")
      p.download_file
    end
  end
  
  describe "platform path" do
    it "should return the path for the platforms" do
      p = Factory.build(:platform)
      p.platform_path.should match(/datafiles\/GPL1355$/)
    end
  end
  
  describe "platform filename" do
    it "should return the path for the platforms" do
      p = Factory.build(:platform)
      p.platform_filename.should match(/datafiles\/GPL1355\/GPL1355.soft$/)
    end
  end

  describe "page" do
    it "should call paginate" do
      Platform.should_receive(:paginate).with({:conditions=>"conditions", :order => [:geo_accession], :page=>2, :per_page=>20}).and_return(true)
      Platform.page("conditions", 2, 20)
    end
  end

end
