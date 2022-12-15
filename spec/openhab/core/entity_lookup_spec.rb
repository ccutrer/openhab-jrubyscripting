# frozen_string_literal: true

RSpec.describe OpenHAB::Core::EntityLookup do
  describe ".capture_items" do
    before do
      items.build do
        group_item Group1 do
          switch_item Switch1
        end

        switch_item Switch2
        group_item gGroup2
      end
    end

    it "captures items" do
      items = described_class.capture_items do
        Switch1 # rubocop:disable Lint/Void
        Switch2
      end
      expect(items).to eql [Switch1, Switch2]
    end

    it "capture group members" do
      items = described_class.capture_items do
        Group1.members
      end
      expect(items).to eql [Group1.members]
    end

    it "captures method missing items" do
      items = described_class.capture_items do
        gGroup2
      end
      expect(items).to eql [gGroup2.members]
    end

    it "captures dummy items" do
      items = rules.build do
        OpenHAB::Core::EntityLookup.capture_items do # rubocop:disable RSpec/DescribedClass
          NonExistentSwitch1
        end
      end

      expect(items.map(&:name)).to eql ["NonExistentSwitch1"]
    end
  end
end
