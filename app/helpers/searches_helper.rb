module SearchesHelper
  STOPWORDS = %w[
    the a an and or but to of in on for is are was were be been being have has had
    do does did will would could should may might must can shall i you he she it we they
    me him her them this that these those what which who whom whose how why where when
    if then so as at by from with about into through during].freeze

  def highlight_query(text, query)
    terms = tokenize(query)
    return h(text) if terms.empty?

    # Prefix-stem matching: "confusion" highlights "confused", "confusing", etc.
    patterns = terms.map { |t| Regexp.new("\\b#{Regexp.escape(t[0, 5])}\\w*", Regexp::IGNORECASE) }
    pattern = Regexp.union(patterns)
    h(text).gsub(pattern) { |m| %(<mark class="bg-amber-100 text-amber-900 rounded px-0.5">#{m}</mark>) }.html_safe
  end

  def similarity_bar(score)
    pct = (score.to_f * 100).clamp(0, 100).round
    color = case pct
            when 70.. then "bg-emerald-500"
            when 45..69 then "bg-amber-500"
            else "bg-slate-300"
            end
    content_tag(:div, class: "inline-block w-16 h-1.5 bg-slate-100 rounded-full overflow-hidden align-middle") do
      content_tag(:div, "", class: "h-full #{color}", style: "width: #{pct}%")
    end
  end

  private

  def tokenize(query)
    query.to_s.downcase.scan(/[a-z0-9]+/).reject { |t| t.length < 3 || STOPWORDS.include?(t) }
  end
end
