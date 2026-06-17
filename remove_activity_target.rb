#!/usr/bin/env ruby
require 'xcodeproj'

PROJECT_PATH = File.expand_path('ClimbReflect.xcodeproj', __dir__)
TARGET_NAME  = 'ClimbReflectActivity'

project = Xcodeproj::Project.open(PROJECT_PATH)

ext_target = project.targets.find { |t| t.name == TARGET_NAME }
unless ext_target
  puts "Target '#{TARGET_NAME}' not found — nothing to do."
  exit 0
end

ios_target = project.targets.find { |t| t.name == 'ClimbReflect' }

# 1. Remove embed phase entries pointing to the extension product
if ios_target
  ios_target.copy_files_build_phases.each do |phase|
    phase.files.each do |f|
      if f.file_ref&.path&.include?(TARGET_NAME)
        phase.files.delete(f)
        puts "Removed embed build file for #{TARGET_NAME}"
      end
    end
    # Remove empty embed phase we created (leave original Watch embed alone)
    if phase.name == 'Embed Foundation Extensions' && phase.files.empty?
      ios_target.build_phases.delete(phase)
      puts "Removed empty 'Embed Foundation Extensions' phase"
    end
  end

  # 2. Remove target dependency from iOS → extension
  ios_target.dependencies.each do |dep|
    if dep.target == ext_target
      ios_target.dependencies.delete(dep)
      puts "Removed target dependency"
    end
  end
end

# 3. Remove the sync group
project.main_group.children.each do |child|
  if child.path == TARGET_NAME
    project.main_group.children.delete(child)
    puts "Removed sync group for #{TARGET_NAME}"
  end
end

# 4. Remove product from Products group
project.main_group.children.each do |child|
  next unless child.respond_to?(:name) && child.name == 'Products'
  child.children.each do |prod|
    if prod.path&.include?(TARGET_NAME)
      child.children.delete(prod)
      puts "Removed product reference #{prod.path}"
    end
  end
end

# 5. Remove the target itself
project.targets.delete(ext_target)
puts "Removed target '#{TARGET_NAME}'"

project.save
puts "Done."
