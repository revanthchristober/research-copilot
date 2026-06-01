module LLM
  module_function

  GENERATION_MODEL = ENV.fetch("LLM_GENERATION_MODEL", "gpt-4o")
  CHEAP_MODEL      = ENV.fetch("LLM_CHEAP_MODEL", "gpt-4o-mini")
  EMBED_MODEL      = ENV.fetch("LLM_EMBED_MODEL", "text-embedding-3-small")
  EMBED_DIM        = 1536

  def complete(messages:, model: GENERATION_MODEL, json: false, schema: nil, max_tokens: nil, temperature: nil)
    params = { model: model, messages: messages }
    params[:max_tokens]      = max_tokens  if max_tokens
    params[:temperature]     = temperature if temperature

    if schema
      params[:response_format] = { type: "json_schema", json_schema: schema }
    elsif json
      params[:response_format] = { type: "json_object" }
    end

    resp = openai.chat(parameters: params)
    resp.dig("choices", 0, "message", "content")
  end

  def complete_json(messages:, model: GENERATION_MODEL, **opts)
    raw = complete(messages: messages, model: model, json: true, **opts)
    JSON.parse(raw)
  end

  def complete_with_schema(messages:, schema:, model: GENERATION_MODEL, **opts)
    raw = complete(messages: messages, model: model, schema: schema, **opts)
    JSON.parse(raw)
  end

  def embed(text)
    resp = openai.embeddings(parameters: { model: EMBED_MODEL, input: text })
    resp.dig("data", 0, "embedding")
  end

  def embed_many(texts)
    resp = openai.embeddings(parameters: { model: EMBED_MODEL, input: texts })
    resp["data"].map { |d| d["embedding"] }
  end

  def openai
    @openai ||= OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
  end

  # When Anthropic credits are available, swap providers here.
  # The interface above (complete, complete_json, embed) stays identical —
  # only this file changes.
  #
  # def anthropic
  #   @anthropic ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
  # end
end
