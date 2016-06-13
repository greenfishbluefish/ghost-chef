describe Util do
  # This method takes the following:
  # 1: an object
  # 2: a method #1 responds to which returns an OpenStruct-like object
  # 3: the Hash of arguments to pass to #2
  # 4. a sequence of methods into the return from #2 which returns an Array|nil
  # 5. a pair of keys used to determine if #2 should be called again and, if so,
  #    what key to merge into #3 to do so.
  # 6. A block which is passed to Enumerable.select() on the Array from #4
  #
  # This method returns the concat()'ed Array with all the values (in order, if
  # any) from applying #6 to the results of applying #4, iterating until #5
  # finishes.
  context "#filter" do
    # Validations:
    # * #1 responds to #2
    # * #3 is a Hash or nil
    # * #4 is a String|Symbol, or an Array of String|Symbol (normalize to Array)
    # * #5 is an Array[String|Symbol] where .size == 2
    # * The RV of #2 will respond to #4[0] (recursively) (1, 2, & 3 levels)
    # * #6 exists and is the signature (Scalar)->Bool

    # Test cases:
    # * Method returns 0 (stop), filter -> 0
    it "returns an empty array on nothing returned" do
      obj = Class.new do
        def method(opts={})
          OpenStruct.new(key1: nil, check: nil)
        end
      end.new
      expect(Util.filter(obj, :method, {}, :key1, [ :check, :next ]) { true }).to eql []
    end

    # * Method returns 1 (stop), filter -> 0
    it "returns one value when one is returned and filter is open" do
      obj = Class.new do
        def method(opts={})
          OpenStruct.new(key1: [ 'a' ], check: nil)
        end
      end.new
      expect(Util.filter(obj, :method, {}, :key1, [ :check, :next ]) { false }).to eql []
    end

    # * Method returns 1 (stop), filter -> 1
    it "returns one value when one is returned and filter is open" do
      obj = Class.new do
        def method(opts={})
          OpenStruct.new(key1: [ 'a' ], check: nil)
        end
      end.new
      expect(Util.filter(obj, :method, {}, :key1, [ :check, :next ]) { true }).to eql ['a']
    end

    context "when 2+1 is returned" do
      let(:obj) {
        Class.new do
          def method(opts={})
            if opts[:next]
              OpenStruct.new(key1: [ 'c' ], check: nil)
            else
              OpenStruct.new(key1: [ 'a', 'b' ], check: 'abcd')
            end
          end
        end.new
      }
      it "returns all values when filter is open" do
        expect(
          Util.filter(obj, :method, {}, :key1, [ :check, :next ]) { true }
        ).to eql ['a', 'b', 'c']
      end
      it "returns no values when filter is closed" do
        expect(
          Util.filter(obj, :method, {}, :key1, [ :check, :next ]) { false }
        ).to eql []
      end
    end

    # * Method returns 2 + 2 + 1 (stop), filter -> 0
    context "when 2+2+1 is returned" do
      let(:obj) {
        Class.new do
          def method(opts={})
            if !opts[:next]
              OpenStruct.new(key1: [ 'a', 'b' ], check: 'abcd')
            elsif opts[:next] == 'abcd'
              OpenStruct.new(key1: [ 'c', 'd' ], check: 'efgh')
            else
              OpenStruct.new(key1: [ 'e' ], check: nil)
            end
          end
        end.new
      }
      it "returns all values when filter is open" do
        expect(
          Util.filter(obj, :method, {}, :key1, [ :check, :next ]) { true }
        ).to eql ['a', 'b', 'c', 'd', 'e']
      end
      it "returns no values when filter is closed" do
        expect(
          Util.filter(obj, :method, {}, :key1, [ :check, :next ]) { false }
        ).to eql []
      end
    end

    # Multiple keys
  end
end
