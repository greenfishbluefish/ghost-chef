RSpec::Matchers.define :descend_match do |expected|
  match do |actual|
    descend_match?(expected: expected, actual: actual)
  end

  # We are seeing if we have a list of values that do not match. If the list is
  # empty, then everything must have matched.
  def descend_match?(expected:, actual:)
    expected.select do |method, value|
      !actual.send(method.to_sym).eql? value
    end.empty?
  end
end
