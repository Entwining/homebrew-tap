# frozen_string_literal: true

require "digest"
require "json"
require "utils/ast"
require "dev-cmd/bottle"

# Keeps PR Ruby as syntax data while binding publication to the tested build.
module BottleReceipt
  module_function

  def source(sha, path)
    raise "Invalid commit identity" unless sha.match?(/\A[0-9a-f]{40}\z/)
    raise "Invalid formula path" unless path.match?(%r{\AFormula/[a-z0-9][a-z0-9+@.-]*\.rb\z})

    Utils.safe_popen_read("git", "show", "#{sha}:#{path}")
  end

  def without_bottle(text)
    ast = Utils::AST::FormulaAST.new(text)
    ast.remove_stanza(:bottle, type: :block_call) if ast.bottle_block
    ast.process
  end

  def recipe(text)
    ast = Utils::AST::FormulaAST.new(text)
    url = ast.stanza(:url)
    raise "Expected a Git tag and immutable revision" unless url&.last_argument&.hash_type?

    specs = url.last_argument.pairs.to_h do |pair|
      [Utils::AST.literal_value(pair.key), Utils::AST.literal_value(pair.value)]
    end
    tag = specs.fetch(:tag)
    revision = specs.fetch(:revision)
    raise "Expected a semantic version tag" unless tag.match?(/\Av\d+\.\d+\.\d+\z/)
    raise "Expected an immutable Git revision" unless revision.match?(/\A[0-9a-f]{40}\z/)

    version = ast.stanza(:version)&.first_argument
    version = version ? Utils::AST.literal_value(version) : tag.delete_prefix("v")
    revision_number = ast.stanza(:revision)&.first_argument
    revision_number = revision_number ? Utils::AST.literal_value(revision_number) : 0
    [PkgVersion.new(Version.new(version), revision_number).to_s, revision]
  end

  def key(record)
    suffix = record.fetch("rebuild").positive? ? ".#{record.fetch("rebuild")}" : ""
    "#{record.fetch("formula")}-#{record.fetch("pkg_version")}#{suffix}"
  end

  def receipt(ref)
    text = Utils.safe_popen_read("git", "for-each-ref", "--format=%(contents)", "refs/tags/#{ref}")
    return if text.strip.empty?

    JSON.parse(text)
  end

  def seed(selection)
    refs = Utils.safe_popen_read("git", "for-each-ref", "--format=%(refname:strip=2)",
                                 "refs/tags/publish/").lines.map(&:strip)
    records = refs.map { |ref| receipt(ref) }.select do |record|
      record.fetch("repository") == selection.fetch("repository") &&
        record.fetch("head_sha") == selection.fetch("head_sha") &&
        selection.fetch("paths").include?(record.fetch("path"))
    end
    identities = records.map { |record| record.slice("run_id", "run_attempt", "artifact_id", "artifact_digest") }.uniq
    raise "Conflicting source-build receipts" if identities.length > 1

    identities.first || {}
  end

  def bottle_block(record)
    name = record.fetch("formula")
    version = record.fetch("pkg_version")
    rebuild = record.fetch("rebuild")
    raise "Invalid formula name" unless name.match?(/\A[a-z0-9][a-z0-9+@.-]*\z/)
    raise "Invalid package version" unless version.match?(/\A\d+\.\d+\.\d+(?:_\d+)?\z/)
    raise "Invalid bottle rebuild" if !rebuild.is_a?(Integer) || rebuild.negative?

    root = "https://github.com/#{record.fetch("repository")}/releases/download/#{name}-#{version}"
    raise "Unexpected bottle root URL" if record.fetch("root_url") != root
    raise "Expected the macos-26 bottle" if record.fetch("bottles").keys != ["arm64_tahoe"]

    spec = BottleSpecification.new
    spec.root_url(root)
    spec.rebuild(rebuild)
    record.fetch("bottles").each do |tag, bottle|
      cellar = bottle.fetch("cellar")
      raise "Unexpected cellar" unless ["any", "any_skip_relocation", "/opt/homebrew/Cellar"].include?(cellar)
      raise "Invalid bottle checksum" unless bottle.fetch("sha256").match?(/\A[0-9a-f]{64}\z/)

      cellar = cellar.to_sym unless cellar.start_with?("/")
      filename = ::Bottle::Filename.new(name, PkgVersion.parse(version), Utils::Bottles::Tag.from_symbol(tag.to_sym),
                                        rebuild)
      if bottle.fetch("filename") != filename.url_encode || bottle.fetch("local_filename") != filename.to_s
        raise "Unexpected bottle filename"
      end

      spec.sha256(cellar: cellar, tag.to_sym => bottle.fetch("sha256"))
    end
    Homebrew::DevCmd::Bottle.new([name]).bottle_output(spec, nil)
  end

  def ready_formulae(selection)
    selection.fetch("paths").map do |path|
      text = source(selection.fetch("head_sha"), path)
      ast = Utils::AST::FormulaAST.new(text)
      return nil unless ast.bottle_block

      name = File.basename(path, ".rb")
      version, = recipe(text)
      rebuild = Utils::AST.body_children(ast.bottle_block.body).find { |node| node.send_type? && node.method_name == :rebuild }
      rebuild = rebuild ? Utils::AST.literal_value(rebuild.first_argument) : 0
      record = receipt("publish/#{key("formula" => name, "pkg_version" => version, "rebuild" => rebuild)}")
      return nil unless record

      raise "Unexpected receipt schema" if record.fetch("schema") != 1
      raise "Receipt targets another formula" if record.values_at("repository", "formula", "path", "pkg_version",
                                                                  "rebuild") !=
                                                 [selection.fetch("repository"), name, path, version, rebuild]

      old_text = source(record.fetch("head_sha"), path)
      blob = Utils.safe_popen_read("git", "rev-parse", "#{record.fetch("head_sha")}:#{path}").strip
      raise "Receipt source blob changed" if blob != record.fetch("formula_blob")
      if Digest::SHA256.hexdigest(without_bottle(old_text)) != record.fetch("source_sha256")
        raise "Receipt source fingerprint changed"
      end

      return nil if Digest::SHA256.hexdigest(without_bottle(text)) != record.fetch("source_sha256")

      expected = Utils::AST::FormulaAST.new("class BottleCheck < Formula\n#{bottle_block(record)}end\n").bottle_block
      return nil if ast.bottle_block != expected

      name
    end
  end

  def plan(selection, directory)
    run = selection.fetch("run")
    artifact = selection.fetch("artifact")
    head = selection.fetch("head_sha")
    raise "Expected a successful pull_request build on the source head" if run.values_at("event", "conclusion",
                                                                                         "head_sha", "path") !=
                                                                           ["pull_request", "success", head,
                                                                            ".github/workflows/tests.yml"]
    raise "Build belongs to another repository" if run.dig("repository",
                                                           "full_name") != selection.fetch("repository")
    raise "Artifact belongs to another build" if artifact.dig("workflow_run",
                                                              "id") != run.fetch("id") || artifact.dig(
                                                                "workflow_run", "head_sha"
                                                              ) != head
    raise "Artifact has expired" if artifact.fetch("expired")
    raise "Artifact has no immutable digest" unless artifact.fetch("digest").match?(/\Asha256:[0-9a-f]{64}\z/)
    if artifact.fetch("name") != "bottles_macos-26-#{run.fetch("run_attempt")}"
      raise "Artifact attempt does not match"
    end

    directory = Pathname(directory)
    entries = directory.children
    raise "Artifact contains a directory or symlink" unless entries.all? { |file| file.lstat.file? && !file.symlink? }

    metadata = directory.glob("*.bottle.json").flat_map { |file| JSON.parse(file.read).values }
    selection.fetch("paths").map do |path|
      text = source(head, path)
      name = File.basename(path, ".rb")
      version, revision = recipe(text)
      matches = metadata.select { |data| data.dig("formula", "name") == name }
      raise "Expected one bottle metadata record for #{name}" unless matches.one?

      data = matches.first
      formula = data.fetch("formula")
      tap_path = "Library/Taps/#{selection.fetch("repository").downcase}/#{path}"
      if formula.values_at("pkg_version", "tap_git_path", "path") != [version, path, tap_path]
        raise "Bottle metadata targets another formula"
      end

      tree = formula.fetch("tap_git_revision")
      raise "Invalid tested commit identity" unless tree.match?(/\A[0-9a-f]{40}\z/)

      unless system("git", "cat-file", "-e", "#{tree}^{commit}", out: File::NULL, err: File::NULL)
        Utils.safe_popen_read("git", "fetch", "--no-tags", "origin", tree)
      end
      parents = Utils.safe_popen_read("git", "show", "-s", "--format=%P", tree).split
      raise "Tested commit is unrelated to the source head" if tree != head && parents.exclude?(head)

      blob = Utils.safe_popen_read("git", "rev-parse", "#{head}:#{path}").strip
      raise "Tested formula differs from the source head" if Utils.safe_popen_read("git", "rev-parse",
                                                                                   "#{tree}:#{path}").strip != blob

      bottle = Homebrew::DevCmd::Bottle.new([name]).merge_json_files([{ name => data }]).fetch(name).fetch("bottle")
      record = {
        "schema" => 1,
        "repository" => selection.fetch("repository"), "pull_request" => selection.fetch("pull_request"),
        "formula" => name, "path" => path, "pkg_version" => version, "head_sha" => head,
        "formula_blob" => blob, "source_sha256" => Digest::SHA256.hexdigest(without_bottle(text)),
        "tested_tree" => tree,
        "run_id" => run.fetch("id"), "run_attempt" => run.fetch("run_attempt"),
        "artifact_id" => artifact.fetch("id"), "artifact_digest" => artifact.fetch("digest"),
        "root_url" => bottle.fetch("root_url"), "rebuild" => bottle.fetch("rebuild"),
        "bottles" => bottle.fetch("tags").transform_values do |tag|
          tag.slice("filename", "local_filename", "sha256", "cellar")
        end
      }
      bottle_block(record)
      bottle.fetch("tags").each_value do |tag|
        raise "Bottle contains another source revision" if tag.dig("tab", "source", "scm_revision") != revision
        if Digest::SHA256.file(directory/tag.fetch("local_filename")).hexdigest != tag.fetch("sha256")
          raise "Bottle checksum differs from its metadata"
        end
      end
      record
    end
  end

  def write_plan(records, directory)
    directory = Pathname(directory)
    (directory/"receipts").mkpath
    (directory/"Formula").mkpath
    (directory/"plan.json").write("#{JSON.pretty_generate(records)}\n")
    records.each do |record|
      (directory/"receipts/#{key(record)}.json").write("#{JSON.pretty_generate(record)}\n")
      text = source(record.fetch("head_sha"), record.fetch("path"))
      ast = Utils::AST::FormulaAST.new(text)
      block = bottle_block(record)
      ast.bottle_block ? ast.replace_bottle_block(block) : ast.add_bottle_block(block)
      result = ast.process
      raise "Change extends outside the bottle block" if without_bottle(result) != without_bottle(text)

      (directory/record.fetch("path")).write(result)
    end
  end

  def commit_input(selection, records)
    branch = selection.fetch("branch")
    additions = records.map do |record|
      path = record.fetch("path")
      ast = Utils::AST::FormulaAST.new(source(selection.fetch("head_sha"), path))
      if Digest::SHA256.hexdigest(without_bottle(ast.process)) != record.fetch("source_sha256")
        raise "Formula source changed during publishing"
      end

      block = bottle_block(record)
      ast.bottle_block ? ast.replace_bottle_block(block) : ast.add_bottle_block(block)
      { "path" => path, "contents" => [ast.process].pack("m0") }
    end
    headline = if records.one?
      "build(#{records.first.fetch("formula")}): add #{records.first.fetch("pkg_version")} bottle"
    else
      "build: add formula bottles"
    end
    {
      "query"     => "mutation($input: CreateCommitOnBranchInput!) { " \
                     "createCommitOnBranch(input: $input) { commit { oid } } }",
      "variables" => { "input" => {
        "branch" => { "repositoryNameWithOwner" => selection.fetch("repository"), "branchName" => branch },
        "expectedHeadOid" => selection.fetch("head_sha"), "fileChanges" => { "additions" => additions },
        "message" => {
          "headline" => headline,
          "body"     => records.map { |record| "Publish-Receipt: publish/#{key(record)}" }.join("\n"),
        }
      } },
    }
  end
end

if $PROGRAM_NAME == __FILE__
  command, selection_path, input_path, output_path = ARGV
  selection = JSON.parse(File.read(selection_path))
  case command
  when "seed"
    puts JSON.generate(BottleReceipt.seed(selection))
  when "status", "check"
    formulae = BottleReceipt.ready_formulae(selection)
    raise "Awaiting source-bound bottles for the changed formulae" if command == "check" && formulae.nil?

    puts JSON.generate("state" => formulae ? "ready" : "prepare", "formulae" => formulae)
  when "plan"
    BottleReceipt.write_plan(BottleReceipt.plan(selection, input_path), output_path)
  when "commit"
    puts JSON.generate(BottleReceipt.commit_input(selection, JSON.parse(File.read(input_path))))
  else
    raise "Unknown bottle receipt operation"
  end
end
