class Annotation < ActiveRecord::Base
  include Utilities
  extend Utilities::ClassMethods

  validates_uniqueness_of :ncbo_id, :scope => [:ontology_term_id, :geo_accession, :field]

  belongs_to :ontology_term, :counter_cache => true
  belongs_to :ontology

  has_many :annotation_closures #, :include => :ontology_term, :order => "ontology_terms.name"

  class << self

    def persist(geo_accession, field_name, ncbo_id, ontology_term_string, text_start, text_end, description)
      ontology_term = OntologyTerm.first(:conditions => {:term_id => ontology_term_string})
      if ontology_term && !annotation = Annotation.first(:conditions => {:geo_accession => geo_accession, :field => field_name, :ontology_term_id => ontology_term.id})
        Annotation.create(:geo_accession => geo_accession, :field => field_name, :ncbo_id => ncbo_id, :ontology_term_id => ontology_term.id, :ontology_id => ontology_term.ontology_id, :from => text_start, :to => text_end, :description => description)
      end
    end

    def count_by_ontology_array
      annotations = {}
      Constants::ONTOLOGIES.keys.each do |key|
        annotations[Constants::ONTOLOGIES[key][:name]] = Annotation.count(:conditions => {:ncbo_id => key})
      end
      array = annotations.sort_by { |k,v| v }
      array.reverse.map { |a| {:name => a[0], :amount => a[1]} }
    end

    def page(conditions, page=1, size=Constants::PER_PAGE)
      paginate(:order => "ontology_terms.name",
               :include => [:ontology_term, :ontology],
               :conditions => conditions,
               :page => page,
               :per_page => size
               )
    end

    def build_cloud(term_array)
      anatomy_terms = OntologyTerm.cloud(:ontology => "Mouse adult gross anatomy").sort_by { |term| term.name.downcase }
      rat_strain_terms = OntologyTerm.cloud(:ontology => "Rat Strain Ontology").sort_by { |term| term.name.downcase }
      @annotation_hash = Annotation.find_by_sql("SELECT * FROM annotations GROUP BY geo_accession ORDER BY geo_accession").inject({}) { |h, a| h[a.geo_accession] = a.description; h }

      if !term_array.blank?
        term_array.each do |term|
          annotations = Annotation.find_by_sql("SELECT annotations.* FROM annotations, ontology_terms WHERE ontology_terms.term_id = '#{term}' AND ontology_terms.id = annotations.ontology_term_id GROUP BY geo_accession ORDER BY geo_accession")
          hash = annotations.inject({}) { |h, a| h[a.geo_accession] = a.description; h }
          intersection = @annotation_hash.keys & hash.keys
          combine = @annotation_hash.dup.update(hash)
          @annotation_hash = {}
          intersection.each {|k| @annotation_hash[k] = combine[k] }
        end

        anatomy_term_ids = anatomy_terms.map { |term| term.term_id }
        rat_strain_term_ids = rat_strain_terms.map { |term| term.term_id }
        term_ids = []
        @annotation_hash.keys.each do |id|
          item = Annotation.load_item(id)
          item.annotations.each do |annotation|
            term_ids << annotation.ontology_term.term_id
          end
        end

        term_ids.uniq!
        at = anatomy_term_ids & term_ids
        rs = rat_strain_term_ids & term_ids
        @anatomy_terms = anatomy_terms.inject([]) { |a, term| a << term if at.include?(term.term_id); a }
        @rat_strain_terms = rat_strain_terms.inject([]) { |a, term| a << term if rs.include?(term.term_id); a }
      else
        @anatomy_terms = anatomy_terms
        @rat_strain_terms = rat_strain_terms
      end

      [@annotation_hash, @anatomy_terms.uniq, @rat_strain_terms.uniq]
    end
  end

  def full_text_highlighted
    text = field_value
    term = "<strong class='highlight'>#{text[(self.from-1)..(self.to-1)]}</strong>"
    if self.from != 1
      term = text[0..(self.from-2)] << term
    end
    
    if self.to != text.size
      term = term << text[self.to..text.size]
    end

    term
  end

  def in_context
    extended = 50
    start = 0
    finish = 0
    text = field_value
    prefix = ""
    suffix = ""
    term = "<strong class='highlight'>#{text[(self.from-1)..(self.to-1)]}</strong>"
    start = (self.from-extended > 0) ? self.from-extended : 0

    if self.from-1 > 0
      if self.from-extended > 0
        prefix = "..."+text[start..(self.from-2)]
      else
        prefix = text[start..(self.from-2)]
      end
    end

    if self.to+extended > text.size
      if self.to+1 <= text.size
        suffix = text[(self.to)..text.size]
      end
    else
      finish = self.to+extended
      suffix = text[(self.to)..finish]+"..."
    end
    prefix+term+suffix
  end

  def field_value
    m = Annotation.load_item(self.geo_accession)
    m.send(field)
  end

  def toggle
    if self.verified?
      self.verified = false
    else
      self.verified = true
    end
    self.audited = true
    self.save
  end

end