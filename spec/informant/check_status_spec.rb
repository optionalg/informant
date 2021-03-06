require 'spec_helper'

describe Informant::CheckStatus do
  with_stub_channels

  before(:each) do
    @config = Informant::Configuration.new
    @config.node("node", :address => "localhost", :commands => %w(a b c))
    @node = @config.nodes['node']
  end

  describe "#report" do
    it "stores the current status of the command" do
      @config.command("check_flapping", :execute => FLAPPING_CHECK, :checks_before_notification => 1)
      command = @config.commands['check_flapping']
      check_status = Informant::CheckStatus.new(@node, command)
      check_status.report(command, Informant::CheckResult.new(:success, "OK"))
      check_status.status.should == :success
      check_status.output.should == "OK"
    end

    it "does not notify the first check if it is successful" do
      @config.command("check_flapping", :execute => FLAPPING_CHECK, :checks_before_notification => 1)
      command = @config.commands['check_flapping']
      check_status = Informant::CheckStatus.new(@node, command)
      check_status.report(command, Informant::CheckResult.new(:success, "OK"))
      Informant.channels.notifications.messages.size.should == 0
    end

    it "notifies on the first check if it has failed" do
      @config.command("check_flapping", :execute => FLAPPING_CHECK, :checks_before_notification => 1)
      command = @config.commands['check_flapping']
      check_status = Informant::CheckStatus.new(@node, command)
      check_status.report(command, Informant::CheckResult.new(:failed, "Uh oh"))
      Informant.channels.notifications.messages.size.should == 1
      message = Informant.channels.notifications.messages.first
      message.node.should == @node
      message.command.should == command
      message.old_result.should be_never_checked
      message.new_result.should be_failed
    end

    it "does not notify again if the status is still failed" do
      @config.command("check_flapping", :execute => FLAPPING_CHECK, :checks_before_notification => 1)
      command = @config.commands['check_flapping']
      check_status = Informant::CheckStatus.new(@node, command)
      check_status.report(command, Informant::CheckResult.new(:failed, "Uh oh"))
      check_status.report(command, Informant::CheckResult.new(:failed, "Uh oh"))
      Informant.channels.notifications.messages.size.should == 1
    end

    it "does not notify unless failed more than checks_before_notification setting" do
      @config.command("check_flapping", :execute => FLAPPING_CHECK, :checks_before_notification => 3)
      command = @config.commands['check_flapping']
      check_status = Informant::CheckStatus.new(@node, command)
      check_status.report(command, Informant::CheckResult.new(:failed, "Uh oh"))
      Informant.channels.notifications.messages.size.should == 0
      check_status.report(command, Informant::CheckResult.new(:failed, "Uh oh"))
      Informant.channels.notifications.messages.size.should == 0
      check_status.report(command, Informant::CheckResult.new(:failed, "Uh oh"))
      Informant.channels.notifications.messages.size.should == 1
    end

    it "notifies when a check goes from failed to passing" do
      @config.command("check_flapping", :execute => FLAPPING_CHECK, :checks_before_notification => 1)
      command = @config.commands['check_flapping']
      check_status = Informant::CheckStatus.new(@node, command)
      check_status.report(command, Informant::CheckResult.new(:failed, "Uh oh"))
      Informant.channels.notifications.messages.size.should == 1
      check_status.report(command, Informant::CheckResult.new(:success, "Great Success"))
      Informant.channels.notifications.messages.size.should == 2
    end

    it "does not repeatedly notify successful checks" do
      @config.command("check_flapping", :execute => FLAPPING_CHECK, :checks_before_notification => 3)
      command = @config.commands['check_flapping']
      check_status = Informant::CheckStatus.new(@node, command)
      check_status.report(command, Informant::CheckResult.new(:success, "Great Success"))
      Informant.channels.notifications.messages.size.should == 0
      check_status.report(command, Informant::CheckResult.new(:success, "Great Success"))
      Informant.channels.notifications.messages.size.should == 0
    end
  end

  describe "#stale?" do
    it "is true when the check has never been checked" do
      @config.command("check_flapping", :execute => FLAPPING_CHECK)
      command = @config.commands['check_flapping']
      check_status = Informant::CheckStatus.new(@node, command)
      check_status.should be_stale
    end

    it "is false when the status has been updated recently" do
      @config.command("check_flapping", :execute => FLAPPING_CHECK, :interval => 15)
      command = @config.commands['check_flapping']
      check_status = Informant::CheckStatus.new(@node, command)
      check_status.report(command, Informant::CheckResult.new(:success, "Great Success", Time.now - 12))
      check_status.should_not be_stale
    end

    it "is true when the status was updated more than the commands interval ago" do
      @config.command("check_flapping", :execute => FLAPPING_CHECK, :interval => 15)
      command = @config.commands['check_flapping']
      check_status = Informant::CheckStatus.new(@node, command)
      check_status.report(command, Informant::CheckResult.new(:success, "Great Success", Time.now - 17))
      check_status.should be_stale
    end
  end

  describe "#reschedule!" do
    it "marks the status as stale" do
      @config.command("check_flapping", :execute => FLAPPING_CHECK, :interval => 15)
      command = @config.commands['check_flapping']
      check_status = Informant::CheckStatus.new(@node, command)
      check_status.report(command, Informant::CheckResult.new(:success, "Great Success", Time.now - 12))
      check_status.should_not be_stale

      check_status.reschedule!
      check_status.should be_stale
    end

    it "is no longer stale after the next reporting" do
      @config.command("check_flapping", :execute => FLAPPING_CHECK, :interval => 15)
      command = @config.commands['check_flapping']
      check_status = Informant::CheckStatus.new(@node, command)
      check_status.report(command, Informant::CheckResult.new(:success, "Great Success", Time.now - 12))
      check_status.should_not be_stale

      check_status.reschedule!
      check_status.report(command, Informant::CheckResult.new(:success, "Great Success", Time.now - 12))
      check_status.should_not be_stale
    end
  end
end
