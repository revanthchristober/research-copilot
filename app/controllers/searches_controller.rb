class SearchesController < ApplicationController
  def show
    @query = params[:q].to_s
    @rerank = ActiveModel::Type::Boolean.new.cast(params[:rerank])

    if @query.strip.empty?
      @results = []
      @timing = nil
      return
    end

    t0 = Time.now
    @results = SearchService.call(query: @query, k: 10, rerank: @rerank)
    @timing = ((Time.now - t0) * 1000).round
  end
end
