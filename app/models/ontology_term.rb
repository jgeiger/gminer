class OntologyTerm < ActiveRecord::Base

  belongs_to :ontology
  has_many :annotations, :order => :geo_accession#, :dependent => :destroy
  has_many :annotation_closures, :include => :annotation, :order => "annotations.geo_accession"#, :dependent => :destroy

#  has n, :results, :foreign_key => :ontology_term_id#, :order => :sample_geo_accession, :dependent => :destroy # they exist, but don't associate in case of lazy load

  class << self
    def page(conditions, page=1, size=Constants::PER_PAGE)
      paginate(:order => [:name],
               :conditions => conditions,
               :page => page,
               :per_page => size
               )
    end

    def cloud(options = {})
      query = "SELECT ontology_terms.*"
      query << " FROM ontology_terms, ontologies, annotations"
      query << " WHERE ontology_terms.annotations_count > 0"
      query << " AND annotations.verified = 1 AND annotations.ontology_term_id = ontology_terms.id" if !options[:invalid]
      query << " AND ontology_terms.ncbo_id = ontologies.ncbo_id AND ontologies.ncbo_id = '#{options[:ontology_ncbo_id]}'" if options[:ontology_ncbo_id]
      query << " GROUP BY ontology_terms.name"
      query << " ORDER BY ontology_terms.annotations_count DESC, ontology_terms.name"
      query << " LIMIT #{options[:limit]}" if options[:limit] != nil
      cloud = OntologyTerm.find_by_sql(query)
    end

    def count_for_probeset(term_id, probeset_id, ncbo_id)
      count(
        :joins => "INNER JOIN annotations ON ontology_terms.id = annotations.ontology_term_id INNER JOIN samples ON annotations.geo_accession = samples.geo_accession INNER JOIN detections ON detections.sample_id = samples.id INNER JOIN probesets ON detections.probeset_id = probesets.id AND ontology_terms.id = #{term_id} AND probesets.id = #{probeset_id} AND annotations.ncbo_id = '#{ncbo_id}' AND annotations.verified = 1"
      )
    end

  end

  def to_param
    self.term_id
  end

  def specific_term_id
    self.term_id.split("|").last
  end

  def valid_annotation_percentage
    if annotations_count > 0
      (valid_annotation_count.to_f/annotations_count.to_f)*100
    else
      0
    end
  end

  def audited_annotation_percentage
    if annotations_count > 0
      (audited_annotation_count.to_f/annotations_count.to_f)*100
    else
      0
    end
  end

  def valid_annotation_count
    Annotation.count(:conditions => {:ontology_term_id => self.id, :verified => true})
  end

  def audited_annotation_count
    Annotation.count(:conditions => {:ontology_term_id => self.id, :audited => true})
  end

  def direct_geo_references
    annotations.inject([]) { |array, a| array << {:geo_accession => a.geo_accession, :description => a.description}; array }
  end

  def closure_geo_references
    annotation_closures.inject([]) { |array, ac| array << {:geo_accession => ac.annotation.geo_accession, :description => ac.annotation.description}; array }
  end

  def parent_closures
    sql = "SELECT DISTINCT ontology_terms.*"
    sql << " FROM annotations, annotation_closures, ontology_terms"
    sql << " WHERE annotations.ontology_term_id = #{self.id}"
    sql << " AND annotations.id = annotation_closures.annotation_id"
    sql << " AND ontology_terms.id = annotation_closures.ontology_term_id"
    sql << " ORDER BY ontology_terms.name"
    terms = OntologyTerm.find_by_sql(sql)
  end

  def child_closures
    acs = AnnotationClosure.all(:conditions => {:ontology_term_id => self.id}, :order => "ontology_terms.name", :include => [:ontology_term])
    terms = acs.inject([]) do |array, ac|
      array << ac.annotation.ontology_term
      array
    end
    terms.uniq
  end

  def link_item(key)
    case key
      when /^GSM/
        m = "samples"
      when /^GSE/
        m = "series_item"
      when /^GPL/
        m = "platforms"
      when /^GDS/
        m = "datasets"
    end
    "<a href='/#{m}/#{key}'>#{key}</a>"
  end

end
