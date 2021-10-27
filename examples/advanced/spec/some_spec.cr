require "./spec_helper"

describe "This" do
  it "works" do
    true.should be_true
  end

  it "fails" do
    false.should eq(true)
  end
end
