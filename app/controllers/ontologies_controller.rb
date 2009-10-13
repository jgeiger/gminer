class OntologiesController < ApplicationController

  def index
    @q = params[:query]
    page = (params[:page].to_i > 0) ? params[:page] : 1

    q_front = "#{@q}%"
    q_both = "%#{@q}%"

    cstring = "name LIKE ?"
    conditions = [cstring, q_front]

    find_ontologies(conditions, page)
    #if we have a page > the last one, redo the query turning the page into the last one
    find_ontologies(conditions, @ontologies.total_pages) if params[:page].to_i > @ontologies.total_pages

    respond_to do |format|
      format.html {}
      format.js  {
          render(:partial => "ontologies_list")
        }
    end
  end

  def show
    @ontology = Ontology.find(params[:id])

    respond_to do |format|
      format.html
    end

    rescue ActiveRecord::RecordNotFound
      flash[:warning] = "That ontology does not exist."
      redirect_to(ontologies_url)
  end

  protected
    def find_ontologies(conditions, page)
      @ontologies = Ontology.page(conditions, page, Constants::PER_PAGE)
    end

end
