# frozen_string_literal: true

class Search::GlobalRequest
  RESULT_LIMIT = 20

  FUZZY_THRESHOLD = 3
  FTS_CANDIDATE_LIMIT = 100
  FUZZY_SCAN_LIMIT = 200

  Entry = Data.define(:entity, :rank, :searchable_type)
  Result = Data.define(:entries)

  class << self
    def call(user:, query:, limit: RESULT_LIMIT)
      new(user:, query:, limit:).call
    end
  end

  def initialize(user:, query:, limit: RESULT_LIMIT)
    @user = user
    @query = query.to_s.strip
    @limit = limit
    @terms = Search::TermBuilder.normalize(@query)
  end

  def call
    return no_result if @query.blank?

    records = Search::Record.search(user: @user, query: @query, limit: FTS_CANDIDATE_LIMIT).to_a
    records = apply_fuzzy_fallback(records) if records.size < FUZZY_THRESHOLD

    ranked_records = rank_records(records)

    Result.new(entries: load_entries(ranked_records))
  end

  private

  def no_result
    Result.new(entries: [])
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

  def rank_records(records)
    records
      .map { |record| { record: record, rank: rank(record) } }
      .sort_by { |ranked| ranked[:rank] }
      .first(@limit)
  end

  def rank(record)
    ranking = record.attributes["fts_rank"].to_f
    name = record.search_name.to_s.downcase
    body = record.search_body.to_s.downcase

    @terms.each do |term|
      ranking -= 5 if name == term
      ranking -= 3 if name.start_with?(term)
      ranking -= 1 if body.include?(term)
    end

    age_days = (Time.current - record.updated_at) / 1.day
    ranking -= [ 3 - age_days / 30.0, 0 ].max

    ranking
  end

  def load_entries(ranked_records)
    records = ranked_records.pluck(:record)
    index = load_entities_for(records)

    ranked_records.filter_map do |ranked|
      record = ranked[:record]
      entity = index[[ record.searchable_type, record.searchable_id ]]
      next unless entity

      Entry.new(entity: entity, rank: ranked[:rank], searchable_type: record.searchable_type)
    end
  end

  def load_entities_for(records)
    index = {}

    records.group_by(&:searchable_type).each do |type, type_records|
      entities = case type
      when "Project" then load_entities(type_records, Project)
      when "Person" then load_entities(type_records, Person)
      when "Bucket" then load_buckets(type_records)
      when "Bullet" then load_bullets(type_records)
      else []
      end

      entities.each { |entity| index[[ type, entity.id ]] = entity }
    end

    index
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
