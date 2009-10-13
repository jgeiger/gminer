class Result < ActiveRecord::Base
  extend Utilities::ClassMethods
  
  validates_uniqueness_of :id_ref, :scope => :sample_id
  validates_uniqueness_of :ontology_term_id, :scope => [:sample_id, :id_ref]

  belongs_to :sample
  belongs_to :ontology_term

  class << self
    def page(conditions, page=1, size=Constants::PER_PAGE)
      paginate(:order => "samples.geo_accession, id_ref, ontology_terms.term_id",
               :conditions => conditions,
               :include => [:sample, :ontology_term],
               :page => page,
               :per_page => size
               )
    end
  end

  def generate_rdf
    id_ref_to_pubmed_id +
    ontology_term_to_geo_accession +
    id_ref_to_geo_accession
  end

  def id_ref_to_pubmed_id
    [id_ref_url, present_in_url, pubmed_id_url, "."].join(" ")+"\n"
  end

  def ontology_term_to_geo_accession
    [ontology_term_url, present_in_url, geo_accession_url, "."].join(" ")+"\n"
  end

  def id_ref_to_geo_accession
    [id_ref_url, present_in_url, geo_accession_url, "."].join(" ")+"\n"
  end

  def present_in_url
    "<http://purl.gminer.mcw.edu/terms#present_in>"
  end

  def geo_accession_url
    "<http://www.ncbi.nlm.nih.gov/geo##{sample_geo_accession}>"
  end

  def pubmed_id_url
    "<#{Constants::RDF_BIO}pubmed:#{pubmed_id}>"
  end

  def id_ref_url
    "<#{Constants::RDF_BIO}affymetrix:#{id_ref}>"
  end

  def ontology_term_url
    ontology_id, term_id = ontology_term_id.split("|")
    case ontology_id
      when "MSH"
        "<#{Constants::RDF_MESH}##{term_id}>"
      when "39234" # rat strain
        "<http://rgd.mcw.edu/strains##{term_id}>"
      when "39278", "39319", "39320" #go
        "<http://www.geneontology.org/terms##{term_id}>"
      when "39310" #mouse gross anatomy
        "<http://purl.org/obo/owl/MA##{term_id.gsub(":", "_")}>"
      when "39242" #mouse gross anatomy
        "<http://purl.org/obo/owl/PW##{term_id.gsub(":", "_")}>"
      when "13578" #NCI Thesaurus
        "<http://purl.org/obo/owl/NCIt#NCIt_#{term_id}>"
      when "39071" #Mammalian Phenotype
        "<http://purl.org/obo/owl/MP##{term_id.gsub(":", "_")}>"
    end
  end

end
