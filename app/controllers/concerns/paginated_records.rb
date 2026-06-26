# frozen_string_literal: true

module PaginatedRecords
  extend ActiveSupport::Concern

  private

  def paginated_portion_from(records, page_param: :page, per_page: nil, ordered_by: nil)
    page = geared_page_from(records, page_param: page_param, per_page: per_page, ordered_by: ordered_by)
    [page.records, page]
  end

  def geared_page_from(records, page_param: :page, per_page: nil, ordered_by: nil)
    GearedPagination::Recordset.new(records, ordered_by: ordered_by, per_page: per_page)
                               .page(params[page_param])
  end
end
