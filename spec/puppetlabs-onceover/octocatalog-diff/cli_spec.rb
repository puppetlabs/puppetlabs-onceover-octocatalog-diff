# frozen_string_literal: true

require 'spec_helper'
require 'facter'
require 'open3'
require 'stringio'

# Small duck-typed stand-ins for PuppetlabsOnceover::Class/Node/Test. The
# real Test class has a heavyweight constructor (it looks up nodes/classes by
# name in global registries maintained by the real onceover gem), so building
# real Test objects here would mean exercising that gem's internals instead
# of this plugin's cli.rb. The `run` block only ever calls
# `test.classes[0].name`, `test.nodes[0].name` and `test.to_s`, so these
# simple structs are enough to drive every branch.
FakeThing = Struct.new(:name)
FakeTest = Struct.new(:classes, :nodes) do
  def to_s
    "#{classes.first.name}_on_#{nodes.first.name}".gsub('::', '__')
  end
end

RSpec.describe PuppetlabsOnceover::CLI::Run::Diff do
  subject(:command) { described_class.command }

  let(:fixtures_dir) { File.expand_path('../../fixtures', __dir__) }
  let(:controlrepo_root) { File.join(fixtures_dir, 'controlrepo') }
  let(:factset_file) { File.join(fixtures_dir, 'factsets', 'test-node-1.json') }

  let(:repo) do
    instance_double(
      PuppetlabsOnceover::Controlrepo,
      root: controlrepo_root,
      facts_files: [factset_file],
      puppetfile: File.join(controlrepo_root, 'Puppetfile'),
      hiera_config_file: File.join(controlrepo_root, 'hiera.yaml'),
      onceover_yaml: File.join(controlrepo_root, 'controlrepo.yaml')
    )
  end

  def stub_test_config(tests)
    test_config = instance_double(PuppetlabsOnceover::TestConfig, spec_tests: [], run_filters: tests)
    allow(PuppetlabsOnceover::TestConfig).to receive(:new).and_return(test_config)
    test_config
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  # Stubs `Open3.popen3` for both call sites in cli.rb: the r10k puppetfile
  # install invocation, and the octocatalog-diff invocation. Which behavior
  # to return for the octocatalog-diff call is chosen per-test by matching a
  # marker substring (the fake node's name) baked into the `--fact-file`
  # argument of the command string, since that's the only thing that varies
  # between calls once everything else is stubbed.
  def stub_popen3(r10k_exitstatus: 0, node_exitstatus: {})
    allow(Open3).to receive(:popen3) do |*args, &block|
      cmd_str = args.first
      stdin = StringIO.new

      if cmd_str.include?('r10k puppetfile install')
        status = double('r10k_status', exitstatus: r10k_exitstatus)
        wait_thr = double('r10k_wait_thr', value: status)
        block.call(stdin, StringIO.new(''), StringIO.new(''), wait_thr)
      else
        marker, exitstatus = node_exitstatus.find { |node_name, _| cmd_str.include?(node_name) }
        status = double('octocatalogdiff_status', exitstatus: exitstatus)
        wait_thr = double('octocatalogdiff_wait_thr', value: status)
        block.call(stdin, StringIO.new("stdout for #{marker}"), StringIO.new("stderr for #{marker}"), wait_thr)
      end
    end
  end

  before do
    allow(PuppetlabsOnceover::Controlrepo).to receive(:new).and_return(repo)
    allow(PuppetlabsOnceover::Test).to receive(:deduplicate) { |tests| tests }
    allow_any_instance_of(Cri::CommandDSL).to receive(:`).and_return("/usr/bin/puppet\n")
  end

  describe '.command' do
    it 'returns a Cri::Command named diff' do
      expect(command).to be_a(Cri::Command)
      expect(command.name).to eq('diff')
    end

    it 'is registered as a subcommand of PuppetlabsOnceover::CLI::Run' do
      expect(PuppetlabsOnceover::CLI::Run.command.subcommands).to include(command)
    end
  end

  describe 'running the diff subcommand' do
    context 'when Facter reports enough processors for one worker thread' do
      before { allow(Facter).to receive(:value).with('processors').and_return('count' => 2) }

      it 'runs one test through to completion, prints a "no differences" summary, and honors --from/--to' do
        test = FakeTest.new([FakeThing.new('role::success')], [FakeThing.new('success-node')])
        stub_test_config([test])
        stub_popen3(node_exitstatus: { 'success-node' => 0 })

        output = capture_stdout { command.run(%w[--from a --to b]) }

        expect(output).to include('Test:')
        expect(output).to include('role::success on success-node')
        expect(output).to match(/Exit:\e\[0m 0/)
        expect(output).to include('no differences')
        expect(Open3).to have_received(:popen3).with(a_string_matching(/--from a --to b/))
      end

      it 'prints a "failed" summary (with stderr) for an exit status of 1' do
        test = FakeTest.new([FakeThing.new('role::failed')], [FakeThing.new('failed-node')])
        stub_test_config([test])
        stub_popen3(node_exitstatus: { 'failed-node' => 1 })

        output = capture_stdout { command.run(%w[--from a --to b]) }

        expect(output).to match(/Exit:\e\[0m 1/)
        expect(output).to include('failed')
        expect(output).to include('stderr for failed-node')
      end

      it 'prints a "changes" summary (with stdout results) for an exit status of 2' do
        test = FakeTest.new([FakeThing.new('role::changed')], [FakeThing.new('changed-node')])
        stub_test_config([test])
        stub_popen3(node_exitstatus: { 'changed-node' => 2 })

        output = capture_stdout { command.run(%w[--from a --to b]) }

        expect(output).to match(/Exit:\e\[0m 2/)
        expect(output).to include('changes')
        expect(output).to include('stdout for changed-node')
      end

      it 'uses the colored gem to style the summary output (ANSI escape codes present)' do
        test = FakeTest.new([FakeThing.new('role::success')], [FakeThing.new('success-node')])
        stub_test_config([test])
        stub_popen3(node_exitstatus: { 'success-node' => 0 })

        output = capture_stdout { command.run(%w[--from a --to b]) }

        # `colored`'s .bold/.yellow/.green/.red all wrap text in ANSI escape
        # sequences; asserting one shows up (rather than merely that the run
        # didn't raise) proves those methods were actually invoked.
        expect(output).to match(/\e\[\d+m/)
      end

      it 'processes multiple queued tests in the same worker thread, exercising both the r10k module-cache-miss and cache-hit branches' do
        tests = [
          FakeTest.new([FakeThing.new('role::success')], [FakeThing.new('success-node')]),
          FakeTest.new([FakeThing.new('role::failed')], [FakeThing.new('failed-node')]),
          FakeTest.new([FakeThing.new('role::changed')], [FakeThing.new('changed-node')])
        ]
        stub_test_config(tests)
        stub_popen3(node_exitstatus: {
                      'success-node' => 0,
                      'failed-node' => 1,
                      'changed-node' => 2
                    })

        output = capture_stdout { command.run(%w[--from a --to b]) }

        expect(output.scan('Test:').count).to eq(3)
        expect(output).to include('no differences')
        expect(output).to include('failed')
        expect(output).to include('changes')
      end

      it 'aborts the whole process when r10k exits non-zero' do
        test = FakeTest.new([FakeThing.new('role::success')], [FakeThing.new('success-node')])
        stub_test_config([test])
        stub_popen3(r10k_exitstatus: 1, node_exitstatus: { 'success-node' => 0 })

        capture_stdout do
          expect { command.run(%w[--from a --to b]) }.to raise_error(SystemExit)
        end
      end
    end

    context 'when Facter reports only one processor' do
      # (Facter.value('processors')['count'] / 2) integer-divides 1 / 2 to 0,
      # so `Array.new(0) { Thread.new { ... } }` spins up zero worker
      # threads. The queue is simply never drained and no test ever runs --
      # this is pre-existing behavior of cli.rb (out of scope to change for
      # this ticket), documented here rather than fixed.
      before { allow(Facter).to receive(:value).with('processors').and_return('count' => 1) }

      it 'spawns no worker threads and silently produces no results' do
        test = FakeTest.new([FakeThing.new('role::success')], [FakeThing.new('success-node')])
        stub_test_config([test])
        stub_popen3(node_exitstatus: { 'success-node' => 0 })

        output = capture_stdout { command.run(%w[--from a --to b]) }

        expect(output).to eq('')
        expect(Open3).not_to have_received(:popen3)
      end
    end
  end
end
