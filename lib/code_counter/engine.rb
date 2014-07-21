require 'set'
require 'code_counter/fs_helpers'
require 'code_counter/reporter'

module CodeCounter
  class Engine
    BIN_DIRECTORIES = Set.new
    STATS_DIRECTORIES = []
    TEST_TYPES = Set.new

    ###########################################################################
    # Mechanisms for configuring the behavior of this tool
    ###########################################################################
    def self.clear!
      BIN_DIRECTORIES.clear
      STATS_DIRECTORIES.clear
      TEST_TYPES.clear
    end

    def self.add_path(key, directory, recursive = true, is_bin_dir = false)
      directory = FSHelpers.canonicalize_directory(directory)
      if directory
        STATS_DIRECTORIES << [key, directory]
        BIN_DIRECTORIES << directory if is_bin_dir
        if recursive
          FSHelpers.enumerate_directories(directory).
            each { |dirent| add_path(key, dirent, recursive, is_bin_dir) }
        end
      end
    end

    def self.add_test_group(key)
      TEST_TYPES << key
    end


    ###########################################################################
    # Default configuration
    ###########################################################################
    DEFAULT_PATHS = [
      ["Controllers", "app/controllers"],
      ["Mailers",     "app/mailers"],
      ["Models",      "app/models"],
      ["Views",       "app/views"],
      ["Helpers",     "app/helpers"],
      ["Binaries",    "bin",              true, true],
      ["Binaries",    "script",           true, true],
      ["Binaries",    "scripts",          true, true],
      ["Libraries",   "lib"],
      ["Source",      "source"],
      ["Source",      "src"],
      ["Unit tests",  "test"],
      ["RSpec specs", "spec"],
      ["Features",    "features"],
    ]

    DEFAULT_TEST_GROUPS = [
      "Unit tests",
      "RSpec specs",
      "Features",
    ]

    def self.init!
      DEFAULT_PATHS.each do |path_info|
        add_path(*path_info)
      end

      DEFAULT_TEST_GROUPS.each do |key|
        add_test_group(key)
      end
    end
    # TODO: THis is janky.  Move this to relevant locations for clarity.
    init!


    ###########################################################################
    # Internals
    ###########################################################################
    # TODO: Handle files like `Gemfile`, and `Rakefile`.
    ALLOWED_EXTENSIONS = [
      '.feature',
      '.gemspec',
      '.rake',
      '.rb',
      '.ru',
    ]

    def initialize(ignore_file_globs = [])
      @reporter     = CodeCounter::Reporter.new

      @bin_dirs     = BIN_DIRECTORIES.dup
      @pairs        = STATS_DIRECTORIES.
        map { |pair| [pair.first, FSHelpers.canonicalize_directory(pair.last)] }.
        compact { |pair| pair.last }
      @ignore_files = collect_files_to_ignore(ignore_file_globs)

      @pairs = coalesce_pairs(@pairs)

      @statistics  = calculate_statistics
      @total       = (@pairs.length > 1) ? calculate_total : nil
    end

    def coalesce_pairs(pairs)
      groups = {}
      paths_seen = {}
      pairs.each do |pair|
        next if(paths_seen[pair.last])
        paths_seen[pair.last] = true
        (groups[pair.first] ||= Set.new) << pair.last
      end
      return groups
    end

    def collect_files_to_ignore(ignore_file_globs)
      files_to_remove = []
      ignore_file_globs.each do |glob|
        files_to_remove.concat(Dir[glob])
      end
      files_to_remove.map { |filepath| File.expand_path(filepath) }
    end

    def to_s
      code  = calculate_code
      tests = calculate_tests
      test_ratio = "1:%.1f" % x_over_y(tests.to_f, code)

      @reporter.report(@total, @pairs, @statistics, code, tests, test_ratio)
    end

    protected

    def calculate_statistics
      @pairs.inject({}) do |stats, pair|
        stats[pair.first] = calculate_group_statistics(pair.first, pair.last)
        stats
      end
    end

    def ignore_file?(file_path)
      @ignore_files.include?(file_path)
    end

    def blank_stats
      return BLANK_STATS_TEMPLATE.dup
    end

    def calculate_group_statistics(group_name, directories, allowed_extensions = ALLOWED_EXTENSIONS)
      stats = blank_stats
      stats['group'] = group_name

      directories.each do |directory|
        Dir.foreach(directory) do |file|
          path = Pathname.new(File.join(directory, file))
          next unless is_eligible_file?(path, allowed_extensions)

          # Now, go ahead and analyze the file.
          File.open(path) do |fh|
            while line = fh.gets
              stats["lines"] += 1
              # TODO: Should we try to count modules?
              stats["classes"] += 1 if line =~ /class [A-Z]/
              # TODO: Incorporate all Cucumber aliases, break out support for
              # TODO: different testing tools into something more
              # TODO: modular/extensible.
              #
              # TODO: Are there alternative syntaxes that this won't pick up
              # TODO: properly?
              stats["methods"] += 1 if line =~ /(def [a-z]|should .* do|test .* do|it .* do|(Given|When|Then) .* do)/
              stats["codelines"] += 1 unless line =~ /^\s*$/ || line =~ /^\s*#/
            end
          end
        end
      end

      stats['m_over_c'] = x_over_y(stats['methods'], stats['classes'])
      stats['loc_over_m'] = compute_effective_loc_over_m(stats)

      return stats
    end

    def is_eligible_file?(path, allowed_extensions)
      is_allowed_kind = FSHelpers.is_allowed_file_type(path, allowed_extensions)
      is_ignored      = ignore_file?(path.to_s)
      is_bin_dir      = @bin_dirs.include?(path.dirname.to_s)

      return false if path.directory? ||
                      is_ignored ||
                      (!is_allowed_kind && is_bin_dir && !FSHelpers.is_shell_program?(path)) ||
                      (!is_allowed_kind && !is_bin_dir)

      return true
    end

    def calculate_total
      total = blank_stats
      @statistics.each_value do |pair|
        pair.each do |k, v|
          total[k] += v if total[k]
        end
      end
      total
    end

    def calculate_code
      calculate_type(false)
    end

    def calculate_tests
      calculate_type(true)
    end

    def calculate_type(test_match)
      return @statistics.
        select { |group, _| TEST_TYPES.include?(group) == test_match }.
        map { |_, stats| stats['codelines'] }.
        inject(0) { |sum, loc| sum + loc }
    end


    def x_over_y(top, bottom)
      return (bottom > 0) ? (top / bottom) : 0
    end


    def compute_effective_loc_over_m(stats)
      # Ugly hack for subtracting out class/end.  >.<
      loc_over_m  = x_over_y(stats['codelines'], stats['methods'])
      loc_over_m -= 2 if loc_over_m >= 2
      return loc_over_m
    end


    BLANK_STATS_TEMPLATE = {
      'lines'     => 0,
      'codelines' => 0,
      'classes'   => 0,
      'methods'   => 0,
    }
  end
end
