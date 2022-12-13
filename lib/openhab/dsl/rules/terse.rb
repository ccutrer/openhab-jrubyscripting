# frozen_string_literal: true

module OpenHAB
  module DSL
    module Rules
      # If you have a single trigger and execution block, you can use a terse rule:
      # All parameters to the trigger are passed through, and an optional `name:` parameter is added.
      #
      # @example
      #   changed TestSwitch do |event|
      #     logger.info("TestSwitch changed to #{event.state}")
      #   end
      #
      # @example
      #   received_command TestSwitch, name: "My Test Switch Rule", command: ON do
      #     logger.info("TestSwitch received command ON")
      #   end
      #
      module Terse
        class << self
          # @!visibility private
          # @!macro def_terse_rule
          #   @!method $1(*args, name :nil, id: nil, **kwargs, &block)
          #   Create a new rule with a $1 trigger.
          #   @param name [String] The name for the rule.
          #   @param id [String] The ID for the rule.
          #   @yield The execution block for the rule.
          #   @return [Core::Rules::Rule]
          #   @see BuilderDSL#$1
          def def_terse_rule(trigger)
            class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
              def #{trigger}(*args, name: nil, id: nil, **kwargs, &block)     # def changed(*args, name: nil, id: nil, **kwargs, &block)
                raise ArgumentError, "Block is required" unless block         #   raise ArgumentError, "Block is required" unless block
                                                                              #
                id ||= NameInference.infer_rule_id_from_block(block)          #   id ||= NameInference.infer_rule_id_from_block(block)
                script = block.source rescue nil                              #   script = block.source rescue nil
                rule name, id: id, script: script, binding: block.binding do  #   rule name, id: id, script: script, binding: block.binding do
                  #{trigger}(*args, **kwargs)                                 #     changed(*args, **kwargs)
                  run(&block)                                                 #     run(&block)
                end                                                           #   end
              end                                                             # end
              module_function #{trigger.inspect}                              # module_function :changed
            RUBY
          end
        end

        def_terse_rule(:changed)
        def_terse_rule(:channel)
        def_terse_rule(:channel_linked)
        def_terse_rule(:channel_unlinked)
        def_terse_rule(:cron)
        def_terse_rule(:every)
        def_terse_rule(:received_command)
        def_terse_rule(:thing_added)
        def_terse_rule(:thing_updated)
        def_terse_rule(:thing_removed)
        def_terse_rule(:updated)
        def_terse_rule(:on_start)

        module_function

        #
        # Create a rule that keeps the item up to date according to the given block
        #
        # @see Core::EntityLookup.capture_items See capture_items for caveats of how to access items in your block.
        #
        # @param [Item] item The item to keep up to date
        # @param [String, nil] name The name for the rule
        # @param [String, nil] id The id for the rule
        # @yield Calculate the new value for the item
        # @yieldreturn [State]
        # @return [Core::Rules::Rule]
        #
        # @example
        #  calculated_item(Furnace_DeltaTemp) { FurnaceSupplyAir_Temp.state - FurnaceReturnAir_Temp.state }
        #
        def calculated_item(item, name: nil, id: nil, &block)
          raise ArgumentError, "Block is required" unless block

          items = Core::EntityLookup.capture_items do
            item.ensure.update(yield)
          end

          name ||= "Calculate the value of #{item}"
          id ||= NameInference.infer_rule_id_from_block(block)
          script = block.source rescue nil # rubocop:disable Style/RescueModifier

          rule name, id: id, script: script, binding: block.binding do
            changed(*items)
            run do
              item.ensure.update(yield)
            end
          end
        end
      end
    end
  end
end
