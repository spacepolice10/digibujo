# frozen_string_literal: true

class Bullets::ExportsController < ApplicationController
  include PrepareBullets

  before_action :prepare_bullets
  before_action :prepare_export_bullets

  def show
    html = render_to_string(
      template: "bullets/exports/show",
      layout: "export",
      formats: [ :html ]
    )
    html = absolutize_root_relative_urls(html)

    send_data html,
      filename: "digibujo-export-#{Date.current.iso8601}.html",
      type: "text/html; charset=utf-8",
      disposition: "attachment"
  end

  private

  def prepare_export_bullets
    @bullets = @bullets
      .includes(:bulletable, bucket: :bucketable)
      .with_rich_text_content
      .reorder(created_at: :asc)
  end

  def absolutize_root_relative_urls(html)
    base = request.base_url
    html.gsub('href="/', "href=\"#{base}/")
        .gsub('src="/', "src=\"#{base}/")
  end
end
