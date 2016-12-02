require_relative 'spec_helper'

include GivenFilesystemSpecHelpers

describe Cli do
  use_given_filesystem

  before(:each) do
    Cli.settings = Settings.new(
      File.expand_path('../../data/trollolorc_with_board_aliases', __FILE__))
    @cli = Cli.new
  end

  it "fetches burndown data from board-list" do
    full_board_mock
    dir = given_directory
    @cli.options = {"board-list" => "spec/data/board-list.yaml",
                    "output" => dir}
    @cli.burndowns
    expect(File.exist?(File.join(dir,"orange/burndown-data-01.yaml")))
    expect(File.exist?(File.join(dir,"blue/burndown-data-01.yaml")))
  end

  it "backups board" do
    expect_any_instance_of(Backup).to receive(:backup)
    @cli.options = {"board-id" => "1234"}
    @cli.backup
  end

  it "backups board using an alias" do
    expect_any_instance_of(Backup).to receive(:backup)
    @cli.options = {"board-id" => "MyTrelloBoard"}
    @cli.backup
  end

  it "gets lists" do
    full_board_mock
    @cli.options = {"board-id" => "53186e8391ef8671265eba9d"}
    expected_output = <<EOT
Sprint Backlog
Doing
Done Sprint 10
Done Sprint 9
Done Sprint 8
Legend
EOT
    expect {
      @cli.get_lists
    }.to output(expected_output).to_stdout


    # Using an alias
    @cli.options = {"board-id" => "MyTrelloBoard"}
    expect {
      @cli.get_lists
    }.to output(expected_output).to_stdout
  end

  it "gets cards" do
    full_board_mock
    @cli.options = {"board-id" => "53186e8391ef8671265eba9d"}
    expected_output = <<EOT
Sprint 3
(3) P1: Fill Backlog column
(5) P4: Read data from Trollolo
(3) P5: Save read data as reference data
Waterline
(8) P6: Celebrate testing board
(2) P2: Fill Doing column
(1) Fix emergency
Burndown chart
Sprint 10
(3) P3: Fill Done columns
(2) Some unplanned work
Burndown chart
Sprint 9
(2) P1: Explain purpose
(2) P2: Create Scrum columns
Burndown chart
Sprint 8
(1) P1: Create Trello Testing Board
(5) P2: Add fancy background
(1) P4: Add legend
Purpose
Background image
EOT
    expect {
      @cli.get_cards
    }.to output(expected_output).to_stdout

    # Using an alias
    @cli.options = {"board-id" => "MyTrelloBoard"}
    expect {
      @cli.get_cards
    }.to output(expected_output).to_stdout
  end

  it "shows the backlog" do
    full_board_mock
    @cli.options = {"board-id" => "53186e8391ef8671265eba9d",
      "backlog-name" => "Sprint Backlog"}
    expected_output = <<EOT

Priority | Points | Title
       1 |      3 | (3) P1: Fill Backlog column
       4 |      5 | (5) P4: Read data from Trollolo
       5 |      3 | (3) P5: Save read data as reference data
       6 |      8 | (8) P6: Celebrate testing board
EOT
    expect {
      @cli.show_backlog
    }.to output(expected_output).to_stdout
  end

  it "shows the velocity line when showing the backlog with --velocity parameter set" do
    full_board_mock
    @cli.options = {"board-id" => "53186e8391ef8671265eba9d", "velocity" => "9",
      "backlog-name" => "Sprint Backlog"}
    velocity = 9
    expected_output = <<EOT

Priority | Points | Title
       1 |      3 | (3) P1: Fill Backlog column
       4 |      5 | (5) P4: Read data from Trollolo
-------------------------
       5 |      3 | (3) P5: Save read data as reference data
       6 |      8 | (8) P6: Celebrate testing board
EOT
    expect {
      @cli.show_backlog
    }.to output(expected_output).to_stdout
  end

  it "gets checklists" do
    full_board_mock
    @cli.options = {"board-id" => "53186e8391ef8671265eba9d"}
    expected_output = <<EOT
Tasks
Tasks
Tasks
Tasks
Tasks
Feedback
Tasks
Tasks
Tasks
Tasks
Tasks
Tasks
EOT
    expect {
      @cli.get_checklists
    }.to output(expected_output).to_stdout

    # Using an alias
    @cli.options = {"board-id" => "MyTrelloBoard"}
    expect {
      @cli.get_checklists
    }.to output(expected_output).to_stdout
  end

  it "gets description" do
    body = <<-EOT
{
  "id": "54ae8485221b1cc5b173e713",
  "desc": "haml"
}
EOT
    stub_request(
      :get, "https://api.trello.com/1/cards/54ae8485221b1cc5b173e713?key=mykey&token=mytoken"
    ).with(
      :headers => {
        'Accept'=>'*/*; q=0.5, application/xml',
        'Accept-Encoding'=>'gzip, deflate',
        'User-Agent'=>'Ruby'
      }
    ).to_return(:status => 200, :body => body, :headers => {})
    @cli.options = {"card-id" => "54ae8485221b1cc5b173e713"}
    expected_output = "haml\n"
    expect {
      @cli.get_description
    }.to output(expected_output).to_stdout
  end

  it "sets description" do
    expect(STDIN).to receive(:read).and_return("My description")
    stub_request(
      :put, "https://api.trello.com/1/cards/54ae8485221b1cc5b173e713/desc?key=mykey&token=mytoken&value=My%20description"
    ).with(
      :headers => {
        'Accept'=>'*/*; q=0.5, application/xml',
        'Accept-Encoding'=>'gzip, deflate',
        'Content-Length'=>'0',
        'Content-Type'=>'application/x-www-form-urlencoded',
        'User-Agent'=>'Ruby'
      }
    ).to_return(:status => 200, :body => "", :headers => {})
    @cli.options = {"card-id" => "54ae8485221b1cc5b173e713"}
    @cli.set_description
    expect(WebMock).to have_requested(:put, "https://api.trello.com/1/cards/54ae8485221b1cc5b173e713/desc?key=mykey&token=mytoken&value=My%20description")
  end

  context "#board_id" do
    before do
      Cli.settings = Settings.new(
        File.expand_path('../../data/trollolorc_with_board_aliases', __FILE__))
      @cli = Cli.new
    end

    it "returns the id when no alias exists" do
      expect(@cli.send(:board_id, "1234")).to eq("1234")
    end

    it "return the id when an alias exists" do
      expect(@cli.send(:board_id, "MyTrelloBoard")).to eq("53186e8391ef8671265eba9d")
    end
  end
end
