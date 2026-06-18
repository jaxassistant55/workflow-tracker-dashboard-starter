#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"

REPO = ENV.fetch("GITHUB_REPOSITORY", "jaxassistant55/workflow-tracker-dashboard-starter")
OFFER_TITLE = "Workflow Tracker Dashboard Starter"
PRICE = "$150"
OFFER_PAGE = "https://jaxassistant55.github.io/jax-micro-offer-studio/ai-workflow-tracker-sprint.html"
READY_FORM = "https://github.com/jaxassistant55/workflow-tracker-dashboard-starter/issues/new?template=ready-to-pay-workflow-tracker-dashboard-starter.yml"
ORDER_BOARD = "https://github.com/jaxassistant55/workflow-tracker-dashboard-starter/issues/1"
PAYMENT_ACTIVATION = "https://jaxassistant55.github.io/jax-micro-offer-studio/payment-activation.html"
ONE_SALE_PAYMENT_PACKETS = "https://jaxassistant55.github.io/jax-micro-offer-studio/one-sale-payment-packets.html"
SAMPLE_GALLERY = "https://jaxassistant55.github.io/jax-micro-offer-studio/one-sale-sample-output-gallery.html"
SAMPLE_GALLERY_RELEASE = "https://github.com/jaxassistant55/jax-micro-offer-studio/releases/tag/one-sale-sample-output-gallery-v1"
SAMPLE_GALLERY_CSV = "https://jaxassistant55.github.io/jax-micro-offer-studio/one_sale_sample_output_gallery.csv"
SAMPLE_GALLERY_JSON = "https://jaxassistant55.github.io/jax-micro-offer-studio/one_sale_sample_output_gallery.json"
ONE_SALE_PAYMENT_PACKET = "https://jaxassistant55.github.io/jax-micro-offer-studio/one-sale-payment-packets.html#central-ai-workflow-tracker-sprint"
ONE_SALE_PAYMENT_PACKET_ID = "OSP-20260616-04-AI-WORKFLOW-TRACKER-SPRINT"
ONE_SALE_PAYMENT_PACKET_INVOICE_LINE = "AI Workflow Tracker Sprint fixed-scope service - $150 - accepted scope or product transfer per https://jaxassistant55.github.io/jax-micro-offer-studio/ai-workflow-tracker-sprint.html"
PAYMENT_HANDOFF = "https://jaxassistant55.github.io/jax-micro-offer-studio/standalone-payment-handoff.html#workflow-tracker-dashboard-starter"
PROOF_MONITOR = "https://jaxassistant55.github.io/jax-micro-offer-studio/proof-monitor.html"
PAID_CATALOG = "https://jaxassistant55.github.io/jax-micro-offer-studio/paid-offer-action-catalog.html"
TERMS_URL = "https://jaxassistant55.github.io/jax-micro-offer-studio/standalone-offer-terms.html#workflow-tracker-dashboard-starter"
EXACT_ACCEPTANCE = "I accept the Workflow Tracker Dashboard Starter fixed-scope work terms at $150. I understand work or transfer starts only after seller-owned external payment proof exists; I will provide only public or buyer-owned/buyer-authorized non-sensitive inputs; the deliverable is limited to the public preview, README/ORDER scope, and accepted ready-to-pay form details; and credentials, account login work, unauthorized private files, confidential regulated data handling, purchasing, publishing changes, ongoing support, custom implementation beyond the accepted scope, or extra revisions are not included unless separately agreed before payment."
MARKER = "<!-- standalone-micro-offer:buyer-response:v1 -->"
ASSISTANT_AUTHORS = %w[jaxassistant55 github-actions[bot]].freeze
RESPONSE_LABELS = {
  "buyer-response-sent" => ["6f42c1", "Safe buyer next-step response has been posted."],
  "payment-proof-needed" => ["fbca04", "External seller-owned payment proof is still required."],
  "ready-for-seller-review" => ["0e8a16", "Seller must review scope, payment route, and delivery boundary."]
}.freeze

def dry_run?
  %w[1 true yes].include?(ENV.fetch("DRY_RUN", "").downcase)
end

def token_env
  token = ENV["GH_TOKEN"] || ENV["GITHUB_TOKEN"]
  token.to_s.empty? ? {} : { "GH_TOKEN" => token }
end

def run_gh(*args, input: nil, allow_failure: false)
  stdout, stderr, status =
    if input.nil?
      Open3.capture3(token_env, "gh", *args)
    else
      Open3.capture3(token_env, "gh", *args, stdin_data: input)
    end
  return [stdout, stderr, status] if allow_failure || status.success?

  raise "gh #{args.join(" ")} failed: #{stderr.strip}"
end

def gh_json(*args)
  stdout, = run_gh(*args)
  stdout.empty? ? {} : JSON.parse(stdout)
end

def event_payload
  event_path = ENV["GITHUB_EVENT_PATH"].to_s
  return nil if event_path.empty? || !File.exist?(event_path)

  JSON.parse(File.read(event_path))
rescue JSON::ParserError
  nil
end

def issue_from_event
  event_payload && event_payload["issue"]
end

def comment_from_event
  event_payload && event_payload["comment"]
end

def issue_number
  [ENV["ISSUE_NUMBER"], ARGV[0]].map(&:to_s).find { |value| !value.empty? }
end

def fetch_issue(repo, number)
  gh_json("api", "repos/#{repo}/issues/#{number}")
end

def label_names(issue)
  issue.fetch("labels", []).map { |label| label.is_a?(Hash) ? label["name"].to_s : label.to_s }
end

def ready_issue?(issue)
  labels = label_names(issue).map(&:downcase)
  title = issue["title"].to_s.downcase
  labels.any? { |label| %w[ready-to-pay ready-to-buy].include?(label) } ||
    title.start_with?("ready to pay:") ||
    title.start_with?("ready to buy:")
end

def paid_order_board_issue?(issue)
  labels = label_names(issue).map(&:downcase)
  title = issue["title"].to_s.downcase
  labels.any? { |label| %w[paid-inquiry order-board product-transfer service-order needs-scope].include?(label) } ||
    title.include?("order board") ||
    title.include?("available now")
end

def ready_buyer_comment?(comment)
  text = comment.to_s.downcase
  return false if text.empty?

  [
    "ready to pay",
    "ready-to-pay",
    "ready to buy",
    "ready-to-buy",
    "i accept",
    "please invoice",
    "send invoice",
    "payment link",
    "checkout link",
    "funded milestone",
    "i want to buy",
    "i want this",
    "buy this",
    "purchase this",
    "place an order",
    "start order",
    "hire you"
  ].any? { |phrase| text.include?(phrase) }
end

def non_buyer_claim_text?(text)
  normalized = text.to_s.downcase
  return true if normalized.include?("/bounty")
  return true if normalized.include?("bounty:") && (normalized.include?("automated") || normalized.include?("ai agent") || normalized.include?("ai fix"))
  return true if normalized.include?("[ai fix]") && normalized.include?("order board:")
  return true if normalized.include?("[claim]") && (normalized.include?("bounty") || normalized.include?("wallet"))
  return true if normalized.include?("wallet") && normalized.include?("base usdc")

  false
end

def existing_response?(repo, number)
  return false if dry_run?

  comments = gh_json("api", "repos/#{repo}/issues/#{number}/comments?per_page=100")
  comments.any? { |comment| comment["body"].to_s.include?(MARKER) }
end

def create_label_if_needed(repo, name, color, description)
  return if dry_run?

  _stdout, stderr, status = run_gh(
    "api", "--method", "POST", "repos/#{repo}/labels",
    "-f", "name=#{name}",
    "-f", "color=#{color}",
    "-f", "description=#{description}",
    allow_failure: true
  )
  return if status.success? || stderr.include?("already_exists") || stderr.include?("Validation Failed")

  warn "Could not create label #{name}: #{stderr.strip}"
end

def add_labels(repo, number)
  return if dry_run?

  RESPONSE_LABELS.each { |name, (color, description)| create_label_if_needed(repo, name, color, description) }
  run_gh(
    "api", "--method", "POST", "repos/#{repo}/issues/#{number}/labels",
    "--input", "-",
    input: JSON.generate(labels: RESPONSE_LABELS.keys)
  )
end

def post_comment(repo, number, body)
  return if dry_run?

  run_gh(
    "api", "--method", "POST", "repos/#{repo}/issues/#{number}/comments",
    "--input", "-",
    input: JSON.generate(body: body)
  )
end

def terms_block
  if TERMS_URL.empty? || EXACT_ACCEPTANCE.empty?
    <<~MD

      Route-specific acceptance:
      - Use the structured form fields and public offer page to lock the fixed scope before payment.
      - If scope changes, clarify the accepted deliverable, deadline, support boundary, and revision boundary before sending any payment route.
    MD
  else
    <<~MD

      Terms and exact acceptance:
      - Terms page: #{TERMS_URL}
      - Exact acceptance statement to provide before payment:
        "#{EXACT_ACCEPTANCE}"
    MD
  end
end


def payment_packet_block
  if !ONE_SALE_PAYMENT_PACKET.empty?
    <<~MD

      Matching one-sale payment packet:
      - Packet: #{ONE_SALE_PAYMENT_PACKET}
      - Packet ID: #{ONE_SALE_PAYMENT_PACKET_ID}
      - Invoice line: #{ONE_SALE_PAYMENT_PACKET_INVOICE_LINE}
      - Use this packet after acceptance to paste a seller-owned checkout, invoice, marketplace order, funded milestone, or payment request URL into the buyer message.
    MD
  else
    <<~MD

      One-sale payment packets:
      - Packet index: #{ONE_SALE_PAYMENT_PACKETS}
      - This route has no exact one-sale packet; use the packet index only if the buyer moves into a $100+ one-sale route, otherwise use the standalone payment handoff below.
    MD
  end
end

def response_body
  <<~MD
    #{MARKER}
    Thanks for opening a ready-to-pay request for #{OFFER_TITLE}.

    Matched route: #{OFFER_TITLE}
    Listed price: #{PRICE}
    Offer page: #{OFFER_PAGE}
    Structured form: #{READY_FORM}
    Order board: #{ORDER_BOARD}

    Exact next steps:
    1. Keep the scope public-safe in this issue. Do not post passwords, payment cards, tax identifiers, private regulated details, confidential files, or screenshots of payment accounts.
    2. Confirm the exact deliverable, deadline, acceptance proof, and any buyer-owned inputs that can safely be shared.
3. Use payment activation only after scope or transfer terms are accepted: #{PAYMENT_ACTIVATION}
4. Use the sample-output gallery to confirm the expected deliverable shape before payment: https://jaxassistant55.github.io/jax-micro-offer-studio/one-sale-sample-output-gallery.html
5. Use the matching one-sale payment packet below when this is a $100+ one-sale route.
6. Payment must happen through a seller-owned external checkout, invoice, marketplace order, payment request, or funded milestone. This GitHub issue is not a checkout and is not payment proof.
7. Paid work or transfer starts only after payment is posted, funded, released, payable, cleared, or otherwise externally provable.
8. After delivery, save the delivery artifact/status and buyer acceptance or platform completion status.
Sample-output proof before payment:
- Gallery: https://jaxassistant55.github.io/jax-micro-offer-studio/one-sale-sample-output-gallery.html
- Release packet: https://github.com/jaxassistant55/jax-micro-offer-studio/releases/tag/one-sale-sample-output-gallery-v1
- CSV: https://jaxassistant55.github.io/jax-micro-offer-studio/one_sale_sample_output_gallery.csv
- JSON: https://jaxassistant55.github.io/jax-micro-offer-studio/one_sale_sample_output_gallery.json
- These samples and release downloads count $0 until accepted scope, external payment proof, delivery proof, and posted/released/payable/cleared funds exist.
#{payment_packet_block}
#{terms_block}

    Payment handoff after exact acceptance: #{PAYMENT_HANDOFF}
        Paid catalog: #{PAID_CATALOG}
    Proof monitor: #{PROOF_MONITOR}

    Money rule: count $0 until a real buyer accepts the fixed scope or transfer terms, pays through a seller-owned external route, receives delivery, and payment is posted/released/payable/cleared.
  MD
end

def emit(result)
  puts JSON.pretty_generate(result)
end

issue = issue_from_event
comment = comment_from_event
number = issue_number
issue = fetch_issue(REPO, number) if number && (issue.nil? || issue["number"].to_s != number)

unless issue
  emit(status: "skipped", reason: "no_issue_context")
  exit 0
end

if issue["pull_request"]
  emit(status: "skipped", reason: "pull_request_not_buyer_issue", issue_number: issue["number"])
  exit 0
end

unless issue["state"].to_s == "open"
  emit(status: "skipped", reason: "issue_not_open", issue_number: issue["number"], state: issue["state"])
  exit 0
end

labels = label_names(issue)
issue_author = issue.dig("user", "login").to_s
comment_author = comment.is_a?(Hash) ? comment.dig("user", "login").to_s : ""
comment_body = comment.is_a?(Hash) ? comment["body"].to_s : ""
trigger_author = comment_body.empty? ? issue_author : comment_author
combined_text = [issue["title"], issue["body"], labels.join(" "), comment_body].join("\n")
ready_from_issue = ready_issue?(issue)
ready_from_comment = !comment_body.empty? && paid_order_board_issue?(issue) && ready_buyer_comment?(comment_body)

unless ready_from_issue || ready_from_comment
  emit(status: "skipped", reason: "not_ready_to_pay_or_buy", issue_number: issue["number"], labels: labels, title: issue["title"], comment_checked: !comment_body.empty?)
  exit 0
end

if ASSISTANT_AUTHORS.include?(trigger_author)
  emit(status: "skipped", reason: "assistant_authored_trigger", issue_number: issue["number"], author: trigger_author)
  exit 0
end

if non_buyer_claim_text?(combined_text)
  emit(status: "skipped", reason: "non_buyer_bounty_or_wallet_claim", issue_number: issue["number"], author: trigger_author)
  exit 0
end

if existing_response?(REPO, issue["number"])
  emit(status: "skipped", reason: "response_already_present", issue_number: issue["number"])
  exit 0
end

body = response_body
add_labels(REPO, issue["number"])
post_comment(REPO, issue["number"], body)
emit(
  status: dry_run? ? "dry_run_ready_to_respond" : "responded",
  repo: REPO,
  issue_number: issue["number"],
  offer: OFFER_TITLE,
  author: trigger_author,
  trigger: comment_body.empty? ? "issue" : "issue_comment",
  ready_from_issue: ready_from_issue,
  ready_from_comment: ready_from_comment,
  response_includes_terms: !TERMS_URL.empty? && body.include?(TERMS_URL),
response_includes_acceptance: !EXACT_ACCEPTANCE.empty? && body.include?(EXACT_ACCEPTANCE),
matched_payment_packet: ONE_SALE_PAYMENT_PACKET.empty? ? nil : ONE_SALE_PAYMENT_PACKET,
response_includes_payment_packet: !ONE_SALE_PAYMENT_PACKET.empty? && body.include?(ONE_SALE_PAYMENT_PACKET),
response_includes_payment_packet_index: body.include?(ONE_SALE_PAYMENT_PACKETS),
response_includes_sample_gallery: body.include?(SAMPLE_GALLERY),
response_includes_sample_gallery_release: body.include?(SAMPLE_GALLERY_RELEASE),
  response_marker: MARKER
)
