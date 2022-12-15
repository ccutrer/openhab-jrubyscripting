# frozen_string_literal: true

RSpec.describe OpenHAB::DSL::Rules::Terse do
  it "works" do
    this = self
    items.build { switch_item "TestSwitch" }
    ran = false
    changed TestSwitch do
      ran = true
      expect(self).to be this
    end
    TestSwitch.on
    expect(ran).to be true
  end

  it "requires a block" do
    items.build { switch_item "TestSwitch" }
    expect { changed(TestSwitch) }.to raise_error(ArgumentError)
  end

  describe "#calculated_item" do
    it "works" do
      items.build do
        number_item Furnace_DeltaTemp
        number_item FurnaceSupplyAir_Temp, state: 80
        number_item FurnaceReturnAir_Temp, state: 70
      end

      calculated_item(Furnace_DeltaTemp) { FurnaceSupplyAir_Temp.state - FurnaceReturnAir_Temp.state }

      expect(Furnace_DeltaTemp.state).to eq 10
      FurnaceReturnAir_Temp.update(71)
      expect(Furnace_DeltaTemp.state).to eq 9
    end

    it "works with a group of items" do
      items.build do
        group_item gTemps do
          number_item Temp1, state: 5
          number_item Temp2, state: 7
        end

        number_item TotalTemp
      end

      calculated_item(TotalTemp) { gTemps.members.map(&:state)&.sum }

      expect(TotalTemp.state).to eq 12

      Temp2.update(9)
      expect(TotalTemp.state).to eq 14
    end
  end
end
