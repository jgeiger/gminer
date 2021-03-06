require 'spec_helper'

describe Sample do

  describe "count_for_probeset" do
    it "should return the count for the selected parameters" do
      Sample.should_receive(:count).with('samples.id', {:joins=>"INNER JOIN annotations ON samples.geo_accession = annotations.geo_accession INNER JOIN ontology_terms ON ontology_terms.id = annotations.ontology_term_id INNER JOIN detections ON detections.sample_id = samples.id INNER JOIN probesets ON detections.probeset_id = probesets.id", :conditions=>["probesets.id = ? AND ontology_terms.id = ? AND annotations.verified = 1", 1, 2], :distinct=>true}).and_return(5)
      Sample.count_for_probeset(1, 2).should == 5
    end
  end

  describe "page" do
    it "should call paginate" do
      Sample.should_receive(:paginate).with({:conditions=>"conditions", :order => :geo_accession, :page=>2, :per_page=>20}).and_return(true)
      Sample.page("conditions", 2, 20)
    end
  end

  describe "create detections" do
    it "should create detections from the sample file" do
      pending ("issues with connection")
      array = [
"#ID_REF = ",
"#VALUE = MAS5-calculated Signal intensity",
"#ABS_CALL = the call in an absolute analysis that indicates if the transcript was present (P), absent (A), marginal (M), or no call (NC)",
"#DETECTION P-VALUE = 'detection p-value', p-value that indicates the significance level of the detection call",
"!sample_table_begin",
"ID_REF  VALUE  ABS_CALL  DETECTION P-VALUE",
"AFFX-BioB-5_at  3893.9  P  0.00034",
"AFFX-BioB-M_at  5571.1  P  0.000044",
"prehashed  5571.1  P  0.000044",
"!sample_table_end"
              ]
      p = Factory.build(:platform)
      si = Factory.build(:series_item)
      s = Factory.build(:sample, :platform => p, :series_item => si)
      s.stub!(:id).and_return(1)
      File.should_receive(:open).with(/datafiles\/GPL1355\/GSE8700\/GSM1234_sample.soft/, "r").and_return(array)
      p1 = Factory.build(:probeset, :name => 'AFFX-BioB-5_at')
      p2 = Factory.build(:probeset, :name => 'AFFX-BioB-M_at')

      Probeset.should_receive(:first).with(:conditions => {:name => 'AFFX-BioB-5_at'}).and_return(nil)
      Probeset.should_receive(:first).with(:conditions => {:name => 'AFFX-BioB-M_at'}).and_return(nil)

      Probeset.should_receive(:create).with(:name => 'AFFX-BioB-5_at').and_return(p1)
      Probeset.should_receive(:create).with(:name => 'AFFX-BioB-M_at').and_return(p2)

      sql = "INSERT INTO detections (sample_id, probeset_id, abs_call) VALUES ('1', '#{p1.id}', 'P'), ('1', '#{p2.id}', 'P')"

      connection = mock("connection")
      connection.stub!(:open_transactions).and_return(true)
      connection.stub!(:rollback_db_transaction).and_return(true)
      connection.stub!(:decrement_open_transactions).and_return(true)
      connection.should_receive(:execute).with(sql).and_return(true)
      ActiveRecord::Base.stub!(:connection).and_return(connection)
      s.create_detections({})
    end

    it "should not create detections from an empty sample file" do
      array = []
      p = Factory.build(:platform)
      si = Factory.build(:series_item)
      s = Factory.build(:sample, :platform => p, :series_item => si)
      File.should_receive(:open).with(/datafiles\/GPL1355\/GSE8700\/GSM1234_sample.soft/, "rb", {:encoding=>"ISO-8859-1"}).and_return(array)
      s.create_detections({})
    end
  end

  describe "create results" do
    before(:each) do
      @detection = mock(Detection, :probeset_id => 9999, :abs_call => "P", :id_ref => "abc")
      @detections = mock("detections")
      @sample = mock(Sample, :id => 2222, :geo_accession => "GSM1234", :pubmed_id => "1234", :ontology_term_id => 1000, :detections => @detections)
      Sample.stub!(:matching).and_return([@sample])

      @connection = mock("connection")
      @connection.stub!(:open_transactions).and_return(true)
      @connection.stub!(:rollback_db_transaction).and_return(true)
      @connection.stub!(:decrement_open_transactions).and_return(true)

    end

    it "should create results for each of the samples and detections" do
      Detection.should_receive(:all).with(:conditions => {:sample_id => 2222, :abs_call => 'P'}).and_return([@detection])
      sql = "INSERT INTO results (sample_id, probeset_id, pubmed_id, ontology_term_id) VALUES ('2222', '9999', '1234', '1000')"
      ActiveRecord::Base.stub!(:connection).and_return(@connection)
      @connection.should_receive(:execute).with(sql).and_return(true)
      Sample.create_results
    end

    it "should not create results for empty inserts" do
      Detection.should_receive(:all).with(:conditions => {:sample_id => 2222, :abs_call => 'P'}).and_return([])
      Sample.create_results
    end
  end

  describe "matching" do
    before(:each) do
      @sample = mock(Sample)
      @options = {:ncbo_id => 1000, :field_name => "source_name", :require_pubmed_id => false}
    end

    it "should return the series geo accessions and pubmed_ids for samples" do
      sql = "SELECT samples.id, samples.geo_accession, series_items.pubmed_id as pubmed_id, ontology_terms.id as ontology_term_id FROM samples, ontology_terms, series_items, annotations, ontologies WHERE ontologies.ncbo_id = 1000 AND ontology_terms.ncbo_id = ontologies.ncbo_id AND annotations.field_name = 'source_name' AND samples.series_item_id = series_items.id AND annotations.ontology_term_id = ontology_terms.id AND annotations.geo_accession = samples.geo_accession"
      Sample.should_receive(:find_by_sql).with(sql).and_return([@sample])
      Sample.matching(@options.merge!({})).should == [@sample]
    end

    it "should return the series geo accessions and pubmed_ids for samples matching the term_id" do
      sample = mock(Sample)
      sql = "SELECT samples.id, samples.geo_accession, series_items.pubmed_id as pubmed_id, ontology_terms.id as ontology_term_id FROM samples, ontology_terms, series_items, annotations, ontologies WHERE ontologies.ncbo_id = 1000 AND ontology_terms.term_id = '1000|MA:1234' AND ontology_terms.ncbo_id = ontologies.ncbo_id AND annotations.field_name = 'source_name' AND samples.series_item_id = series_items.id AND annotations.ontology_term_id = ontology_terms.id AND annotations.geo_accession = samples.geo_accession"
      Sample.should_receive(:find_by_sql).with(sql).and_return([@sample])
      Sample.matching(@options.merge!({:term_id => "1000|MA:1234"})).should == [@sample]
    end

    it "should return the series geo accessions and pubmed_ids for samples requiring a pubmed_id on series" do
      sample = mock(Sample)
      sql = "SELECT samples.id, samples.geo_accession, series_items.pubmed_id as pubmed_id, ontology_terms.id as ontology_term_id FROM samples, ontology_terms, series_items, annotations, ontologies WHERE ontologies.ncbo_id = 1000 AND ontology_terms.ncbo_id = ontologies.ncbo_id AND annotations.field_name = 'source_name' AND series_items.pubmed_id != '' AND samples.series_item_id = series_items.id AND annotations.ontology_term_id = ontology_terms.id AND annotations.geo_accession = samples.geo_accession"
      Sample.should_receive(:find_by_sql).with(sql).and_return([@sample])
      Sample.matching(@options.merge!({:require_pubmed_id => true})).should == [@sample]
    end
  end

end
