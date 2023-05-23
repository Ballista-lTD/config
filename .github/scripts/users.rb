require 'yaml'
require 'set'

def parsed_predicate(val)
  v = val.sub(/\s*#.*\z/, "")
  { key: v } unless v.include?(";")
end

def parsed_data(filename)
  result = {}
  content = File.read(filename).split(/\n/)
  content.each do |raw_line|
    line = raw_line.strip

    # Ignore comments and blank lines
    next if line.start_with?("#") || line == ""

    # Ensure valid lines
    unless line =~ /\A([\w\-]+)\s*([&!]?=)\s*(.+?)\s*\z/
      raise "Unparseable line #{line.inspect} in #{filename}!"
    end

    # Parsing
    raw_key, operator, val = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)

    key = if ["expiration"].include?(raw_key)
            "modifier_#{raw_key}"
          else
            raw_key
          end

    # Contractor function is used internally but may not be specified in the file by the user.
    if key == "contractor"
      raise "Rule Error: #{key} is not a valid function in #{filename}!"
    end

    result[key] ||= {}
    result[key]["="] ||= []
    result[key]["!="] ||= []
    result[key]["&="] ||= []

    # Semicolon predicates
    if key == "description"
      result[key][operator] << { key: val }
    else
      result[key][operator] << parsed_predicate(val)
    end
  end

  result
end

def get_users(filenames)
  users_set = Set.new

  filenames.each do |filename|
    users = parsed_data(filename).find { |k, v| k == "username" }
    users[1]["="].each { |entry|
      users_set.add(entry[:key])
    }
  end

  users_set
end

def update_people(filename, new_users)
  if File.exist?(filename) && !File.empty?(filename)
    # Load the existing YAML file
    yaml = YAML.load_file(filename)
  else
    # Create a new empty data structure
    yaml = {}
  end

  users = yaml.map { |entry| entry[0] }

  new_users.each do |user|
    unless users.include?(user)
      yaml[user] = {
        "dn" => "uid=#{user},ou=People,dc=ballista,dc=tech",
        "githubdotcomid" => user,
        "manager" => "rohittp0"
      }
    end
  end

  File.open(filename, "w") { |f| f.write(yaml.to_yaml) }
end

users_in_txt = get_users(Dir.glob("github.com/Ballista-lTD/**/*.txt").select { |e| File.file? e })
update_people("config/people.yaml", users_in_txt)