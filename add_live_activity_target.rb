#!/usr/bin/env ruby
require 'xcodeproj'

PROJECT_PATH = File.expand_path('ClimbReflect.xcodeproj', __dir__)
TEAM_ID      = 'DCXAD9B8Q3'
BUNDLE_ID    = 'de.dreselbjoern.ClimbReflect.ClimbReflectActivity'
TARGET_NAME  = 'ClimbReflectActivity'
DEPLOY       = '17.0'
SWIFT_VER    = '5.0'

project = Xcodeproj::Project.open(PROJECT_PATH)
ios_target = project.targets.find { |t| t.name == 'ClimbReflect' }
abort('iOS target not found') unless ios_target

if project.targets.any? { |t| t.name == TARGET_NAME }
  puts "Target '#{TARGET_NAME}' already exists — skipping."
  exit 0
end

# ── 1. PBXFileSystemSynchronizedRootGroup for ClimbReflectActivity ──────────
sync_group = project.new(Xcodeproj::Project::Object::PBXFileSystemSynchronizedRootGroup)
sync_group.path = TARGET_NAME
sync_group.source_tree = '<group>'
project.main_group.children << sync_group

# ── 2. Product file reference ────────────────────────────────────────────────
products_group = project.main_group.children.find { |c| c.respond_to?(:name) && c.name == 'Products' }
products_group ||= project.main_group
ext_product_ref = project.new(Xcodeproj::Project::Object::PBXFileReference)
ext_product_ref.explicit_file_type = 'com.apple.product-type.app-extension'
ext_product_ref.include_in_index   = '0'
ext_product_ref.path               = "#{TARGET_NAME}.appex"
ext_product_ref.source_tree        = 'BUILT_PRODUCTS_DIR'
products_group.children << ext_product_ref

# ── 3. Build phases ──────────────────────────────────────────────────────────
sources_phase    = project.new(Xcodeproj::Project::Object::PBXSourcesBuildPhase)
frameworks_phase = project.new(Xcodeproj::Project::Object::PBXFrameworksBuildPhase)
resources_phase  = project.new(Xcodeproj::Project::Object::PBXResourcesBuildPhase)

# ── 4. Build configurations ──────────────────────────────────────────────────
def make_config(project, name, settings)
  config = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  config.name = name
  config.build_settings = settings
  config
end

shared_settings = {
  'ALWAYS_SEARCH_USER_PATHS'               => 'NO',
  'CODE_SIGN_STYLE'                        => 'Automatic',
  'DEVELOPMENT_TEAM'                       => TEAM_ID,
  'GENERATE_INFOPLIST_FILE'                => 'YES',
  'INFOPLIST_KEY_CFBundleDisplayName'      => 'ClimbReflect',
  'INFOPLIST_KEY_NSExtension_NSExtensionPointIdentifier' => 'com.apple.widgetkit-extension',
  'IPHONEOS_DEPLOYMENT_TARGET'             => DEPLOY,
  'PRODUCT_BUNDLE_IDENTIFIER'              => BUNDLE_ID,
  'PRODUCT_NAME'                           => TARGET_NAME,
  'SKIP_INSTALL'                           => 'YES',
  'SWIFT_EMIT_LOC_STRINGS'                 => 'YES',
  'SWIFT_VERSION'                          => SWIFT_VER,
  'TARGETED_DEVICE_FAMILY'                 => '1,2',
}

debug_config   = make_config(project, 'Debug',   shared_settings.merge('DEBUG_INFORMATION_FORMAT' => 'dwarf', 'SWIFT_OPTIMIZATION_LEVEL' => '-Onone'))
release_config = make_config(project, 'Release', shared_settings.merge('DEBUG_INFORMATION_FORMAT' => 'dwarf-with-dsym', 'SWIFT_OPTIMIZATION_LEVEL' => '-O'))

config_list = project.new(Xcodeproj::Project::Object::XCConfigurationList)
config_list.build_configurations << debug_config
config_list.build_configurations << release_config
config_list.default_configuration_name = 'Release'

# ── 5. Native Target ─────────────────────────────────────────────────────────
ext_target = project.new(Xcodeproj::Project::Object::PBXNativeTarget)
ext_target.name                       = TARGET_NAME
ext_target.product_name               = TARGET_NAME
ext_target.product_type               = 'com.apple.product-type.widgetkit-extension'
ext_target.product_reference          = ext_product_ref
ext_target.build_configuration_list   = config_list
ext_target.build_phases << sources_phase
ext_target.build_phases << frameworks_phase
ext_target.build_phases << resources_phase
ext_target.file_system_synchronized_groups << sync_group
project.targets << ext_target

# ── 6. Embed extension in iOS app ────────────────────────────────────────────
embed_phase = ios_target.copy_files_build_phases.find { |p| p.dst_subfolder_spec == '13' }
unless embed_phase
  embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed_phase.name                  = 'Embed Foundation Extensions'
  embed_phase.dst_subfolder_spec    = '13'
  embed_phase.build_action_mask     = '2147483647'
  embed_phase.run_only_for_deployment_postprocessing = '0'
  ios_target.build_phases << embed_phase
end

embed_build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
embed_build_file.file_ref = ext_product_ref
embed_build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
embed_phase.files << embed_build_file

# ── 7. Target dependency iOS app → extension ─────────────────────────────────
container_proxy = project.new(Xcodeproj::Project::Object::PBXContainerItemProxy)
container_proxy.container_portal  = project.root_object.uuid
container_proxy.proxy_type        = '1'
container_proxy.remote_global_id_string = ext_target.uuid
container_proxy.remote_info       = TARGET_NAME

target_dep = project.new(Xcodeproj::Project::Object::PBXTargetDependency)
target_dep.target       = ext_target
target_dep.target_proxy = container_proxy
ios_target.dependencies << target_dep

project.save
puts "Done. Added '#{TARGET_NAME}' Widget Extension target."
