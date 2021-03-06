module Abstract
  module SeriesItem
    include FileUtilities
    extend FileUtilities::ClassMethods
    include Cytoscape

    def to_param
      self.geo_accession
    end

    def series_path
      "#{Rails.root}/datafiles/#{self.platform.geo_accession}/#{self.geo_accession}"
    end

    def family_filename
      "#{self.geo_accession}_family.soft"
    end

    def local_family_filename
      "#{series_path}/#{family_filename}"
    end

    def local_series_filename
      "#{series_path}/#{self.geo_accession}_series.soft"
    end

    def download
      if !File.exists?("#{local_family_filename}")
        download_file
        split_series_file
      end
    end

    def persist
      download
      self.overall_design = join_item(series_hash["overall_design"])
      self.title = join_item(series_hash["title"])
      self.summary = join_item(series_hash["summary"])
      self.pubmed_id = join_item(series_hash["pubmed_id"])
      save!
      self
    end

    def download_file
      make_directory(series_path)
      Net::FTP.open('ftp.ncbi.nih.gov') do |ftp|
        ftp.login
        ftp.passive = true
        files = ftp.chdir("/pub/geo/DATA/SOFT/by_series/#{self.geo_accession}")
        ftp.getbinaryfile("#{family_filename}.gz", "#{local_family_filename}.gz", 1024)
      end
      gunzip("#{local_family_filename}.gz")
    end

    def field_array
      fields = [
        {:name => "title", :annotatable => true, :value => title, :regex => /^!Series_title = (.+)$/},
        {:name => "summary", :annotatable => true, :value => summary, :regex => /^!Series_summary = (.+)$/},
        {:name => "overall_design", :annotatable => true, :value => overall_design, :regex => /^!Series_overall_design = (.+?)$/},
        {:name => "pubmed_id", :annotatable => false, :value => pubmed_id, :regex => /^!Series_pubmed_id = (\d+)$/},
        {:name => "sample_ids", :annotatable => false, :value => "", :regex => /^!Series_sample_id = (GSM\d+)$/}
      ]
    end

    def series_hash
      @series_hash ||= file_hash(field_array, local_series_filename)
    end

    def split_series_file
      text = ""
      outfile = local_series_filename
      start = /^\^SAMPLE = (GSM\d+)$/
      platform_start = /^\^PLATFORM = (GPL\d+)$/
      platform_end = /^!platform_table_end$/
      platform_flag = false

      File.open(local_family_filename, "rb", :encoding => 'ISO-8859-1').each do |line|
        platform_flag = true if line.match(platform_start)
        if m = line.match(start)
          write_file(outfile, text)
          text = ""
          outfile = "#{series_path}/#{m[1]}_sample.soft"
        end
        text << line if !platform_flag
        platform_flag = false if line.match(platform_end)
      end
      write_file(outfile, text)
    end
  end
end
