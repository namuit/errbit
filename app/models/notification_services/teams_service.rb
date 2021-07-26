class NotificationServices::TeamsService < NotificationService # rubocop:disable Style/ClassAndModuleChildren
  LABEL = "teams"
  FIELDS = [
    [:service_url, {
      placeholder: 'Teams Webhook URL (https://XXXXX.webhook.office.com/webhookb2/XXXXXX/IncomingWebhook/XXXXXXX)',
      label:       'URL'
    }]
  ]

  def check_params
    if FIELDS.detect { |f| self[f[0]].blank? }
      errors.add :base, 'You must specify the URL'
    end
  end

  def create_notification(problem)
    HTTParty.post(service_url, headers: { 'Content-Type' => 'application/json' }, body: post_payload(problem).to_json)
  end

private

  def post_payload(problem)
    {
      "summary"         => post_payload_title(problem),
      "themeColor"      => "0078D7",
      "title"           => post_payload_title(problem),
      "sections"        => [
        {
          "activityTitle" => problem.message,
          "facts"         => post_payload_facts(problem)
        }
      ],
      "potentialAction" => post_payload_actions(problem)
    }
  end

  def post_payload_title(problem)
    error_title = problem.error_class || problem.message
    "[#{problem.app.name}] #{error_title}"
  end

  def post_payload_facts(problem)
    [
      fact("Application:", problem.app.name),
      fact("Environment:", problem.environment),
      fact("Where:", problem.where),
      fact("Times Occurred:", problem.notices_count.try(:to_s)),
      fact(
        "First Noticed:",
        problem.first_notice_at.try(:localtime).try(:to_s, :db)
      ),
      fact("Backtrace:", backtrace_lines(problem))
    ]
  end

  def fact(name, value)
    {
      "name"  => name,
      "value" => value
    }
  end

  def post_payload_actions(problem)
    [
      {
        "@type"   => "OpenUri",
        "name"    => "View in Errbit",
        "targets" => [
          {
            "os"  => "default",
            "uri" => problem.url
          }
        ]
      }
    ]
  end

  def backtrace_line(line)
    path = line.decorated_path.gsub(%r{</?strong>}, '')
    "#{path}#{line.file_name}:#{line.number} → #{line.method}\n"
  end

  def backtrace_lines(problem)
    notice = NoticeDecorator.new problem.notices.last
    return unless notice
    backtrace = notice.backtrace
    return unless backtrace

    output = ''
    backtrace.lines[0..4].each { |line| output << backtrace_line(line) }
    "```#{output}```"
  end
end
