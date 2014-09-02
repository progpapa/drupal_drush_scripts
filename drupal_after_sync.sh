#!/usr/bin/env drush

# USAGE:
# drupal_after_sync.sh -y --liveurl="http://www.example.com"
# i)  use -y if you want to skip confirmation when modules are enabled
# ii) use the liveurl option to configure stage_file_proxy, value should be
#     the url of the live site
#
# This file includes things to do after syncing a site to your local computer:
# - download and enable developer modules
# - enable ui modules
# - change username and password of user 1 to admin/admin
# - configure the views_ui module to use dev settings (show advanced tab, etc.)
# - configure basic system variables (caching, css aggregation, etc.)
# - configure stage_file_proxy_module

# Make sure there is a Drupal site to use.
$alias = drush_sitealias_get_record('@self');
if (empty($alias)) {
  drush_set_error('AFTER_SYNC_NO_DRUPAL',
    dt('You are not in a Drupal root directory.'));
  die;
}

# unset liveurl if it was specified, it interferes with drush_shell_exec()
if ($liveurl = drush_get_option('liveurl')) {
  drush_unset_option('liveurl');
}

$dev_modules = array(
  'admin_menu',
  'dblog',
  'devel',
  'module_filter',
  'search_krumo',
  'stage_file_proxy',
);

# This list also includes submodules that cannot be downloaded but should be enabled.
$dev_modules_all = $dev_modules;
$dev_modules_all[] = 'admin_menu_toolbar';

# Generate a list of modules that are already enabled.
drush_shell_exec('drush pml --pipe --type="module" --status=enabled');
$enabled_modules = drush_shell_exec_output();

# Make sure UI modules are enabled.
$ui_modules = array(
  'views' => 'views_ui',
  'rules' => 'rules_admin',
  'context' => 'context_ui',
);
foreach ($ui_modules as $module => $ui_module) {
  if (in_array($module, $enabled_modules)) {
    $dev_modules_all[] = $ui_module;
  }
}

# Generate a list of modules that are disabled or downloaded but has not yet been installed.
drush_shell_exec('drush pml --pipe --type="module" --status="disabled,not installed"');
$disabled_modules = drush_shell_exec_output();

# These should be downloaded and enabled.
$download = array_diff($dev_modules, $enabled_modules, $disabled_modules);
foreach ($download as $module) {
  drush_invoke('pm-download', array($module));
  drush_invoke('pm-enable', array($module));
}

# These should be enabled.
$enable = array_diff($dev_modules_all, $enabled_modules, $download);
foreach ($enable as $module) {
  drush_invoke('pm-enable', array($module));
}

# Disable the following modules.
$disliked_modules = array('overlay', 'toolbar');
foreach (array_intersect($disliked_modules, $enabled_modules) as $module) {
  drush_invoke('pm-disable', array($module));
}

# Dev settings for the views module.
if (module_exists('views_ui')) {
  drush_shell_exec('drush views-dev');
}

# Set temporary files directory.
drush_shell_exec("drush variable-set file_temporary_path /tmp");
# Disable caching and css/js aggregation.
drush_shell_exec("drush variable-set cache 0");
drush_shell_exec("drush variable-set block_cache 0");
drush_shell_exec("drush variable-set page_compression 0");
drush_shell_exec("drush variable-set preprocess_css 0");
drush_shell_exec("drush variable-set preprocess_js 0");
# Show error messages.
drush_shell_exec("drush variable-set error_level 2");

# Change the name for user 1 to "admin".
drush_shell_exec('drush sql-query --db-prefix "update {users} set name=\"admin\" where uid = 1"');
# Reset admin user password to "admin".
drush_shell_exec('drush user-password --password=admin admin');

# stage_file_proxy settings
if (isset($liveurl)) {
  drush_shell_exec("drush variable-set stage_file_proxy_origin $liveurl");
}
else {
  drush_log(dt("Stage file proxy origin not set.\nRun: drush vset stage_file_proxy_origin \"http://www.example.com\""), 'warning');
}
drush_shell_exec('drush variable-set stage_file_proxy_hotlink 1');
