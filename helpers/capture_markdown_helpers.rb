include ActionView::Helpers::SanitizeHelper

module CaptureMarkdownHelpers
  def capture_markdown(&block)
    ExternalDoc.parse(capture(&block).strip)
  end
end
