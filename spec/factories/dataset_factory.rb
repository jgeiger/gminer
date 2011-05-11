# The same, but using a string instead of class constant
Factory.define :dataset, :class => Dataset do |d|
  d.geo_accession 'GDS8700'
  d.reference_series 'GSE8700'
  d.title 'rat strain dataset'
  d.description 'rat strain description'
  d.organism  'rat'
  d.pubmed_id '1234'
  d.association :platform, :factory => :platform
end
