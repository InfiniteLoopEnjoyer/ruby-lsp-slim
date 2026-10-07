# frozen_string_literal: true

# Helpers the example template calls without a receiver
module GreetingHelper
  # The classes of one part of a greeting card
  def greeting_classes(part)
    "greeting greeting-#{ part }"
  end

  # Hello, or something more formal
  def salutation(name, formal: false)
    formal ? "Good day, #{ name }." : "Hi #{ name }!"
  end
end
