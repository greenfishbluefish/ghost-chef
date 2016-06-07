# Notes:
# The AWS stub_responses() method will set a response for all calls to that
# method. If you call it more than once, then the last call wins. If you call it
# with multiple responses, then it will go through the responses until it gets
# to the last one which will then be returned each subsequent call.
#
# Therefore, we have to ensure each AWS call is made exactly the right number of
# times with the appropriate parameters.
module AwsStubs

  # This will receive an array of tuples, of the form: [
  #   [ :method1, <params1>, <response1> ]
  #   [ :method2, <params2>, <response2> ]
  #   [ :method1, <params3>, <response3> ]
  # ]
	def stub_calls(*expectations)
    requests = {}
    expectations.each do |slice|
      method = slice.shift.to_sym
      expectations = slice.pop
      params = slice.first || {}

      requests[method] ||= []
      requests[method].push(expectations)
      requests[method].flatten!

      expect(client).to receive(method)
        .with(params)
        .and_call_original
    end

		requests.each do |method, responses|
			client.stub_responses(method, responses)
		end
	end
end
