# frozen_string_literal: true

class ApplicationParanoia < ApplicationRecord
  self.abstract_class = true

  acts_as_paranoid
end
