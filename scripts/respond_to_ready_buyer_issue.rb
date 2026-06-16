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

def issue_from_event
  event_path = ENV["GITHUB_EVENT_PATH"].to_s
  return nil if event_path.empty? || !File.exist?(event_path)

  event = JSON.parse(File.read(event_path))
  event["issue"]
rescue JSON::ParserError
  nil
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
    4. Payment must happen through a seller-owned external checkout, invoice, marketplace order, payment request, or funded milestone. This GitHub issue is not a checkout and is not payment proof.
    5. Paid work or transfer starts only after payment is posted, funded, released, payable, cleared, or otherwise externally provable.
    6. After delivery, save the delivery artifact/status and buyer acceptance or platform completion status.
    #{terms_block}

    Paid catalog: #{PAID_CATALOG}
    Proof monitor: #{PROOF_MONITOR}

    Money rule: count $0 until a real buyer accepts the fixed scope or transfer terms, pays through a seller-owned external route, receives delivery, and payment is posted/released/payable/cleared.
  MD
end

def emit(result)
  puts JSON.pretty_generate(result)
end

issue = issue_from_event
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

author = issue.dig("user", "login").to_s
if ASSISTANT_AUTHORS.include?(author)
  emit(status: "skipped", reason: "assistant_authored_issue", issue_number: issue["number"], author: author)
  exit 0
end

combined_text = [issue["title"], issue["body"]].join("\n")
unless ready_issue?(issue)
  emit(status: "skipped", reason: "not_ready_to_pay_or_buy", issue_number: issue["number"], labels: label_names(issue), title: issue["title"])
  exit 0
end

if non_buyer_claim_text?(combined_text)
  emit(status: "skipped", reason: "non_buyer_bounty_or_wallet_claim", issue_number: issue["number"])
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
  response_includes_terms: !TERMS_URL.empty? && body.include?(TERMS_URL),
  response_includes_acceptance: !EXACT_ACCEPTANCE.empty? && body.include?(EXACT_ACCEPTANCE),
  response_marker: MARKER
)
