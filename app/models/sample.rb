class Sample < ActiveRecord::Base
  include Utilities
  extend Utilities::ClassMethods

  belongs_to :series_item
  belongs_to :platform
  has_many :detections
#  has n, :results, :foreign_key => :sample_geo_accession # they exist, but don't associate in case of lazy load

  class << self
    def page(conditions, page=1, size=Constants::PER_PAGE)
      paginate(:order => [:geo_accession],
               :conditions => conditions,
               :page => page,
               :per_page => size
               )
    end

    def matching(options)
      sql = "SELECT samples.geo_accession, series_items.pubmed_id as pubmed_id, ontology_terms.term_id as ontology_term_id FROM samples, ontology_terms, series_items, annotations, ontologies "
      sql << "WHERE ontology_terms.name = '#{options[:term]}' "
      sql << "AND ontologies.name = '#{options[:ontology_name]}' "
      sql << "AND ontology_terms.ncbo_id = ontologies.ncbo_id "
      sql << "AND annotations.field = '#{options[:field]}' " 
      sql << "AND series_items.pubmed_id != '' "
      sql << "AND samples.series_geo_accession = series_items.geo_accession "
      sql << "AND annotations.ontology_term_id = ontology_terms.term_id "
      sql << "AND annotations.geo_accession = samples.geo_accession "
      sql << "GROUP BY samples.geo_accession"
      samples = Sample.find_by_sql(sql)
    end

    def create_results(passed = {})
      options = {:ontology_name => "Mouse adult gross anatomy", :field => "source_name"}.merge(passed)
      Sample.matching(options).each do |sample|
        Result.transaction do
          inserts = []
          earlier = Time.new
          sample.detections.find(:all, :conditions => {:abs_call => 'P'}).each do |detection|
            inserts.push "('#{sample.id}', '#{detection.id_ref}', '#{sample.pubmed_id}', '#{sample.ontology_term_id}')"
          end

          if inserts.any?
            sql = "INSERT INTO results (sample_id, id_ref, pubmed_id, ontology_term_id) VALUES #{inserts.join(", ")}"
            begin
              ActiveRecord::Base.connection.execute(sql)
              puts "Sample #{sample.geo_accession} took #{Time.new-earlier}" if options[:debug]
            rescue ActiveRecord::StatementInvalid => e
              if e.message =~ /Mysql::Error: Duplicate entry/
                puts "Mysql::Error: Duplicate entry #{sample.geo_accession} #{sample.ontology_term_id}"
              else
                raise e
              end
            end
          else
            puts "Sample #{sample.geo_accession} had no inserts" if options[:debug]
          end
        end
      end
    end
  end

  def to_param
    self.geo_accession
  end

  def series_path
    "#{Rails.root}/datafiles/#{self.platform.geo_accession}/#{self.series_item.geo_accession}"
  end

  def local_sample_filename
    "#{series_path}/#{self.geo_accession}_sample.soft"    
  end

  def fields
    fields = [
      {:name => "title", :value => title, :regex => /^!Sample_title = (.+)$/},
      {:name => "sample_type", :value => sample_type, :regex => /^!Sample_type = (.+?)$/},
      {:name => "source_name", :value => source_name, :regex => /^!Sample_source_name_ch1 = (.+?)$/},
      {:name => "organism", :value => organism, :regex => /^!Sample_organism_ch1 = (.+?)$/},
      {:name => "characteristics", :value => characteristics, :regex => /^!Sample_characteristics_ch1 = (.+?)$/},
      {:name => "treatment_protocol", :value => treatment_protocol, :regex => /^!Sample_treatment_protocol_ch1 = (.+?)$/},
      {:name => "extract_protocol", :value => extract_protocol, :regex => /^!Sample_extract_protocol_ch1 = (.+?)$/},
      {:name => "label", :value => label, :regex => /^!Sample_label_ch1 = (.+?)$/},
      {:name => "label_protocol", :value => label_protocol, :regex => /^!Sample_label_protocol_ch1 = (.+?)$/},
      {:name => "scan_protocol", :value => scan_protocol, :regex => /^!Sample_scan_protocol = (.+?)$/},
      {:name => "hyp_protocol", :value => hyp_protocol, :regex => /^!Sample_hyb_protocol = (.+?)$/},
      {:name => "description", :value => description, :regex => /^!Sample_description = (.+?)$/},
      {:name => "data_processing", :value => data_processing, :regex => /^!Sample_data_processing = (.+?)$/},
      {:name => "molecule", :value => molecule, :regex => /^!Sample_molecule_ch1 = (.+?)$/},
    ]
  end

  def sample_hash
    hash = file_hash(fields, local_sample_filename)
    hash.keys.each do |key|
      hash[key] = join_item(hash[key])
    end
    hash
  end

  def persist
    self.attributes = sample_hash
    save!
  end

  def create_detections
    data_regex = /^.+_at/
    abs_call_regex = /^#ABS_CALL/
    header_regex = /^ID_REF/
    start_table_regex = /^!sample_table_begin/
    end_table_regex = /^!sample_table_end/

    inserts = []
    abs_call_flag = false
    intable_flag = false
    id_ref_header_pos = nil
    abs_call_header_pos = nil
    mass_header_pos = nil
    significance_header_pos = nil

    File.open(local_sample_filename, "r").each do |line|
      if !abs_call_flag
        abs_call_flag = line =~ abs_call_regex
        next
      end

      if line =~ header_regex
        headers = line.chomp.split("\t")
        id_ref_header_pos = headers.index("ID_REF")
        abs_call_header_pos = headers.index("ABS_CALL")
        abs_call_flag = (headers.include?("ID_REF") && headers.include?("ABS_CALL"))
      end

      if line =~ end_table_regex
        intable_flag = false
      end

      if intable_flag
        if line =~ data_regex
          data = line.chomp.split("\t")
          if (data[id_ref_header_pos] && data[abs_call_header_pos])
            inserts.push "('#{self.id}', '#{data[id_ref_header_pos].chomp}', '#{data[abs_call_header_pos].chomp}')"
          end
        end
      end

      if line =~ start_table_regex
        intable_flag = true
      end
    end

    if inserts.any?
      sql = "INSERT INTO detections (sample_id, id_ref, abs_call) VALUES #{inserts.join(", ")}"
      ActiveRecord::Base.connection.execute(sql)
    end

  end

end
