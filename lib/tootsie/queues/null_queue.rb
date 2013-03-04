module Tootsie

  # Queue which does not nothing.
  class NullQueue

    def initialize
    end

    def count
      0
    end

    def push(item)
    end

    def pop(options = {})
    end

  end

end