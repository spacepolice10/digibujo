# frozen_string_literal: true

class Search::GlobalRequest
  ENTITY_LIMITS = {
    "Project" => 5,
    "Bucket" => 5,
    "Bullet" => 8,
    "Person" => 5
  }.freeze

  FUZZY_THRESHOLD = 3
  FTS_CANDIDATE_LIMIT = 100
  FUZZY_SCAN_LIMIT = 200

  Result = Data.define(:projects, :buckets, :bullets, :people)

  class << self
    def call(user:, query:, limits: ENTITY_LIMITS)
      new(user:, query:, limits:).call
    end
  end

  def initialize(user:, query:, limits: ENTITY_LIMITS)
    @user = user
    @query = query.to_s.strip
    @limits = limits
    @terms = Search::TermBuilder.normalize(@query)
  end

  def call
    return no_result if @query.blank?

    records = Search::Record.search(user: @user, query: @query, limit: FTS_CANDIDATE_LIMIT).to_a
    records = apply_fuzzy_fallback(records) if records.size < FUZZY_THRESHOLD

    grouped = rank_and_group(records)

    Result.new(
      projects: load_entities(grouped.fetch("Project", []), Project),
      buckets: load_buckets(grouped.fetch("Bucket", [])),
      bullets: load_bullets(grouped.fetch("Bullet", [])),
      people: load_entities(grouped.fetch("Person", []), Person)
    )
  end

  private

  def no_result
    Result.new(projects: [], buckets: [], bullets: [], people: [])
  end

  def apply_fuzzy_fallback(records)
    existing_ids = records.map(&:id).to_set

    supplemental = Search::Record.where(user_id: @user.id)
      .where.not(id: existing_ids.to_a)
      .limit(FUZZY_SCAN_LIMIT)
      .select do |record|
        fuzzy_match?(record)
      end

    records + supplemental
  end

  def fuzzy_match?(record)
    haystack = [ record.search_name, record.search_body ].join(" ").downcase
    haystack_words = haystack.split(/\s+/)

    @terms.all? do |term|
      haystack.include?(term) ||
        (term.length >= 3 && haystack_words.any? { |word| DidYouMean::Levenshtein.distance(word, term) <= 1 })
    end
  end

  def rank_and_group(records)
    ranked = records.sort_by { |record| score(record) }

    ranked.group_by(&:searchable_type).transform_values do |entity_records|
      limit = @limits.fetch(entity_records.first.searchable_type, 5)
      entity_records.first(limit)
    end
  end

  def score(record)
    score = record.attributes["fts_rank"].to_f
    name = record.search_name.to_s.downcase
    body = record.search_body.to_s.downcase

    @terms.each do |term|
      score -= 5 if name == term
      score -= 3 if name.start_with?(term)
      score -= 1 if body.include?(term)
    end

    age_days = (Time.current - record.updated_at) / 1.day
    score -= [ 3 - age_days / 30.0, 0 ].max

    score
  end

  def load_entities(records, klass)
    ids = records.map(&:searchable_id)
    indexed = klass.where(id: ids).index_by(&:id)
    ids.filter_map { |id| indexed[id] }
  end

  def load_buckets(records)
    ids = records.map(&:searchable_id)
    indexed = Bucket.where(id: ids).includes(:bucketable, :bullets).index_by(&:id)
    ids.filter_map { |id| indexed[id] }
  end

  def load_bullets(records)
    ids = records.map(&:searchable_id)
    indexed = Bullet.where(id: ids).includes(:projects, bucket: :bucketable).index_by(&:id)
    ids.filter_map { |id| indexed[id] }
  end
end
