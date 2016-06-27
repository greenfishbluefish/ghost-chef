describe GhostChef::Util do
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
    # * The RV of #2 will respond to #4[0] (recursively) (N levels)
    #   * Descending will catch where #2 doesn't respond to #4
    # * The RV from #2.#4 will be an Array or falsy
    # * #6 exists and is the signature (Scalar)->Bool

    # Test cases:
    context "when 0 is returned" do
      let (:obj) {
        Class.new do
          def method(opts={})
            OpenStruct.new(key1: nil, check: nil)
          end
        end.new
      }

      it "returns no values when filter is closed" do
        expect(described_class.filter(obj, :method, {}, :key1, [ :check, :next ]) { false }).to eql []
      end
      it "returns no values when filter is open" do
        expect(described_class.filter(obj, :method, {}, :key1, [ :check, :next ]) { true }).to eql []
      end
    end

    context "when 1 is returned" do
      let (:obj) {
        Class.new do
          def method(opts={})
            OpenStruct.new(key1: [ 'a' ], check: nil)
          end
        end.new
      }

      it "returns no values when filter is closed" do
        expect(described_class.filter(obj, :method, {}, :key1, [ :check, :next ]) { false }).to eql []
      end
      it "returns all values when filter is open" do
        expect(described_class.filter(obj, :method, {}, :key1, [ :check, :next ]) { true }).to eql ['a']
      end
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
          described_class.filter(obj, :method, {}, :key1, [ :check, :next ]) { true }
        ).to eql ['a', 'b', 'c']
      end
      it "returns no values when filter is closed" do
        expect(
          described_class.filter(obj, :method, {}, :key1, [ :check, :next ]) { false }
        ).to eql []
      end
    end

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
          described_class.filter(obj, :method, {}, :key1, [ :check, :next ]) { true }
        ).to eql ['a', 'b', 'c', 'd', 'e']
      end
      it "returns no values when filter is closed" do
        expect(
          described_class.filter(obj, :method, {}, :key1, [ :check, :next ]) { false }
        ).to eql []
      end
    end

    # The CloudFront requires you to descend one level to get to the master RV.
    # Every other client returns the master RV directly.
    context "when descending multiple keys (method)" do
      context "when 1 is returned, 2 keys" do
        let (:obj) {
          Class.new do
            def method(opts={})
              OpenStruct.new(key1: OpenStruct.new(key2: [ 'a' ], check: nil))
            end
          end.new
        }

        it "returns no values when filter is closed" do
          expect(described_class.filter(obj, [:method, :key1], {}, :key2, [ :check, :next ]) { false }).to eql []
        end
        it "returns all values when filter is open" do
          expect(described_class.filter(obj, [:method, :key1], {}, :key2, [ :check, :next ]) { true }).to eql ['a']
        end
      end

      context "when 2+2+1 is returned, 3 keys" do
        let(:obj) {
          Class.new do
            def method(opts={})
              if !opts[:next]
                build(['a', 'b'], 'abcd')
              elsif opts[:next] == 'abcd'
                build(['c', 'd'], 'efgh')
              else
                build(['e'], nil)
              end
            end
            private
            def build(value, check)
              OpenStruct.new(
                key1: OpenStruct.new(
                  key2: OpenStruct.new(
                    key3: value,
                    check: check,
                  ),
                ),
              )
            end
          end.new
        }

        it "returns all values when filter is open" do
          expect(
            described_class.filter(obj, %w(method key1 key2), {}, %w(key3), [ :check, :next ]) { true }
          ).to eql ['a', 'b', 'c', 'd', 'e']
        end
        it "returns no values when filter is closed" do
          expect(
            described_class.filter(obj, %w(method key1 key2), {}, %w(key3), [ :check, :next ]) { false }
          ).to eql []
        end
      end
    end

    context "when descending multiple keys (filter)" do
      context "when 1 is returned, 2 keys" do
        let (:obj) {
          Class.new do
            def method(opts={})
              OpenStruct.new(key1: OpenStruct.new(key2: [ 'a' ]), check: nil)
            end
          end.new
        }

        it "returns no values when filter is closed" do
          expect(described_class.filter(obj, :method, {}, [:key1, :key2], [ :check, :next ]) { false }).to eql []
        end
        it "returns all values when filter is open" do
          expect(described_class.filter(obj, :method, {}, [:key1, :key2], [ :check, :next ]) { true }).to eql ['a']
        end
      end

      context "when 2+2+1 is returned, 3 keys" do
        let(:obj) {
          Class.new do
            def method(opts={})
              if !opts[:next]
                build(['a', 'b'], 'abcd')
              elsif opts[:next] == 'abcd'
                build(['c', 'd'], 'efgh')
              else
                build(['e'], nil)
              end
            end
            private
            def build(value, check)
              OpenStruct.new(
                key1: OpenStruct.new(
                  key2: OpenStruct.new(
                    key3: value,
                  ),
                ),
                check: check,
              )
            end
          end.new
        }

        it "returns all values when filter is open" do
          expect(
            described_class.filter(obj, :method, {}, %w(key1 key2 key3), [ :check, :next ]) { true }
          ).to eql ['a', 'b', 'c', 'd', 'e']
        end
        it "returns no values when filter is closed" do
          expect(
            described_class.filter(obj, :method, {}, %w(key1 key2 key3), [ :check, :next ]) { false }
          ).to eql []
        end
      end
    end
  end

  context '#tags_from_hash' do
    it 'handles an empty hash' do
      expect(described_class.tags_from_hash({})).to eql([])
    end

    it 'handles one key' do
      expect(described_class.tags_from_hash({a:1})).to eql([
        {key: 'a', value: 1},
      ])
    end
  end
end
