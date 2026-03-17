# frozen_string_literal: true

class FlashComponent < ViewComponent::Base
  TYPE_STYLES = {
    notice: {
      container: 'border-emerald-500 bg-emerald-600 text-white shadow-emerald-900/15',
      icon_wrapper: 'bg-white/16 text-white',
      icon: 'circle-check'
    },
    success: {
      container: 'border-emerald-500 bg-emerald-600 text-white shadow-emerald-900/15',
      icon_wrapper: 'bg-white/16 text-white',
      icon: 'circle-check'
    },
    alert: {
      container: 'border-rose-500 bg-rose-600 text-white shadow-rose-900/15',
      icon_wrapper: 'bg-white/16 text-white',
      icon: 'circle-alert'
    },
    error: {
      container: 'border-rose-500 bg-rose-600 text-white shadow-rose-900/15',
      icon_wrapper: 'bg-white/16 text-white',
      icon: 'circle-alert'
    },
    warning: {
      container: 'border-amber-400 bg-amber-300 text-amber-950 shadow-amber-900/15',
      icon_wrapper: 'bg-black/8 text-amber-950',
      icon: 'triangle-alert'
    },
    info: {
      container: 'border-sky-500 bg-sky-600 text-white shadow-sky-900/15',
      icon_wrapper: 'bg-white/16 text-white',
      icon: 'info'
    }
  }.freeze

  def initialize(flash:)
    @flash = flash
  end

  private

  attr_reader :flash

  def messages
    flash.to_hash.filter_map do |type, message|
      next if message.blank?

      Array(message).filter_map do |entry|
        next if entry.blank?

        {
          type: type.to_sym,
          message: entry,
          style: TYPE_STYLES.fetch(type.to_sym, TYPE_STYLES[:info])
        }
      end
    end.flatten
  end
end
