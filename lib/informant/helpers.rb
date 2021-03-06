module Informant
  module Helpers
    def id_for_status(status)
      "#{status.node.name}_#{status.command.name}"
    end

    def label_class_for_status(status)
      case status
      when :success then "label-success"
      when :failed then "label-important"
      else "label-warning"
      end
    end

    def hidden_if_empty(count)
      count > 0 ? '' : 'hide'
    end

    def http_date(time)
      return nil unless time
      time.httpdate
    end

    def tab_class(tab, active_tab)
      if tab == active_tab
        "active"
      else
        ""
      end
    end
  end
end
